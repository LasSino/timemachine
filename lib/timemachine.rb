# frozen_string_literal: true

require 'thread_executor'

module TimeMachine
  TimedTask = Struct.new(:handle, :timeup, :block)
  TaskResult = Struct.new(:handle, :status, :record_result, :result)

  class DuplicateHandleError < RuntimeError; end

  class TimeMachine
    SCHEDULER_DEFAULT_TIMEOUT = 3
    RANDOM_HANDLE_LENGTH = 16
    private_constant :SCHEDULER_DEFAULT_TIMEOUT

    public
    def initialize(executor= Executors::ThreadExecutor.new, more_timely=false)
      @running = false
      @timeout_queue = []

      @result_queue = {}
      @pending_schedule_queue = []
      @cancel_queue = []

      @executor = executor
      @scheduler_thread = nil
      @scheduler_mut = if more_timely then Mutex.new else nil end
      @user_mut = Mutex.new
    end

    def at(timeup, name: nil, record_result: false, &block)
      handle = name || _generate_handle

      @user_mut.synchronize do
        raise DuplicateHandleError if @result_queue.key? handle
        result_slot = TaskResult.new(handle, :UNSCHEDULED, record_result, nil)
        @result_queue[handle] = result_slot
        @pending_schedule_queue << TimedTask.new(
          handle, timeup, block
        )
      end

      _bg_wakeup
      handle
    end

    def after(timeout, name: nil, record_result: false, &block)
      at(Time.now + timeout, name: name, record_result: record_result, &block)
    end

    def get_result(handle)
      @user_mut.synchronize do
        @result_queue[handle]
      end
    end

    def pop_result(handle)
      @user_mut.synchronize do
        res = @result_queue[handle]
        if res&.status==:FINISHED || res&.status==:CANCELLED
          @result_queue.delete(handle)
        else
          res
        end
      end
    end

    def cancel(handle)
      @user_mut.synchronize do
        @cancel_queue << handle
      end
      _bg_wakeup
    end

    def start()
      @user_mut.synchronize do
        return if @running
        @running = true
        @scheduler_thread = Thread.new { _bg_run() }
      end
    end

    def stop()
      @user_mut.synchronize do
        return unless @running
        @running = false
        @result_queue.each_key { |h| @cancel_queue << h}
      end
      _bg_wakeup
    end

    private
    def _generate_handle
      h = (Time.now.to_f * 1000).to_i.to_s(36)
      padding_len = RANDOM_HANDLE_LENGTH - h.size
      randstr = Random.rand(('z'*padding_len).to_i(36))
                  .to_s(36).rjust(padding_len, '0')
      h + randstr
    end

    def _bg_wakeup
      @scheduler_mut&.lock
      @scheduler_thread.run
      @scheduler_mut&.unlock
    end

    def _bg_run
      @scheduler_mut&.lock
      while @running
        @user_mut.synchronize do
          @cancel_queue.each { |h| _bg_cancelTask(h) }
          @cancel_queue.clear
          @pending_schedule_queue.each { |t| _bg_enqueueTask(t) }
          @pending_schedule_queue.clear
        end

        abs_t = Time.now
        ind = @timeout_queue.index { |t| t.timeup > abs_t } || @timeout_queue.size

        @timeout_queue[0...ind].each do |t|
          break if !@running
          _bg_dispatchTask(t)
        end

        @timeout_queue = @timeout_queue[ind..]

        timeout = (
          @timeout_queue[0]&.timeup || 
          (abs_t + SCHEDULER_DEFAULT_TIMEOUT)
        ) - abs_t
        timeout = 0 if timeout < 0

        @scheduler_mut&.unlock
        sleep timeout
        @scheduler_mut&.lock        
      end
      @scheduler_mut&.unlock
    end

    def _bg_enqueueTask(task)
      return if @result_queue[task.handle].status != :UNSCHEDULED

      @result_queue[task.handle].status = :PENDING
      @timeout_queue.insert(@timeout_queue.index do |t|
        t.timeup > task.timeup
      end || -1, task)
    end

    def _bg_cancelTask(handle)
      result_slot = @result_queue[handle]
      case result_slot&.status
      when :UNSCHEDULED
        result_slot.status = :CANCELLED
      when :PENDING
        result_slot.status = :CANCELLED
        @timeout_queue.delete_if do |task|
          task.handle == handle
        end
      end

      @result_queue.delete(handle) unless result_slot&.record_result
    end

    def _bg_dispatchTask(task)
      return if !@running
      result_slot = @result_queue[task.handle]
      return if result_slot&.status != :PENDING

      result_slot.status = :RUNNING
      @executor.execute do
        result_slot&.result = task.block.call
        @user_mut.synchronize {
          result_slot.record_result ? (result_slot&.status = :FINISHED) : @result_queue.delete(task.handle)
        }
      end
    end
  end
  
end
