# frozen_string_literal: true

require 'thread_executor'

module TimeMachine
  TimedTask = Struct.new(:handle, :timeup, :block)
  TaskResult = Struct.new(:handle, :status, :result)

  class DuplicateHandleError < RuntimeError; end

  class TimeMachine
    SCHEDULER_DEFAULT_TIMEOUT = 3
    RANDOM_HANDLE_LENGTH = 16
    private_constant :SCHEDULER_DEFAULT_TIMEOUT

    public
    def initialize(executor= Executors::ThreadExecutor.new, more_timely=false)
      @running = false
      @result_queue = {}
      @timeout_queue = []
      @pending_schedule_queue = []
      @cancel_queue = []
      @executor = executor
      @scheduler_thread = nil
      @scheduler_running_mut = if more_timely then Mutex.new else nil end
    end

    def at(timeup, name: nil, &block)
      handle = name || _generate_handle
      raise DuplicateHandleError if @result_queue.key? handle

      result_slot = TaskResult.new(handle, :UNSCHEDULED, nil)
      @result_queue[handle] = result_slot
      @pending_schedule_queue << TimedTask.new(
        handle, timeup, block
      )
      _bg_wakeup
      handle
    end

    def after(timeout, name: nil, &block)
      at(Time.now + timeout, name: name, &block)
    end

    def lookup(handle)
      @result_queue[handle]
    end

    def cancel(handle)
      @cancel_queue << handle
      _bg_wakeup
    end

    def start()
      return if @running
      @running = true
      @scheduler_thread = Thread.new { _bg_run() }
    end

    def stop()
      @running = false
      @result_queue.each_key { |h| @cancel_queue << h}
      @scheduler_thread._bg_wakeup
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
      @scheduler_running_mut&.lock
      @scheduler_thread.run
      @scheduler_running_mut&.unlock
    end

    def _bg_run
      @scheduler_running_mut&.lock
      while @running
        timeout = (
          @timeout_queue[0]&.timeup || 
          (Time.now + SCHEDULER_DEFAULT_TIMEOUT)
        ) - Time.now
        timeout = 0 if timeout < 0
        @scheduler_running_mut&.unlock
        sleep(timeout)
        @scheduler_running_mut&.lock
        @cancel_queue.each { |h| _bg_cancelTask(h) }
        @pending_schedule_queue.each { |t| _bg_enqueueTask(t) }
        @timeout_queue.each do |t|
          break if t.timeup > Time.now
          break if !@running

          _bg_dispatchTask(t)
        end
      end
      @scheduler_running_mut&.unlock
    end

    def _bg_enqueueTask(task)
      return if @result_queue[task.handle].status != :UNSCHEDULED

      @result_queue[task.handle].status = :PENDING
      @timeout_queue << task
      @timeout_queue.insert(@timeout_queue.index do |t|
        t.timeup > task.timeup
      end || -1, task)
    end

    def _bg_cancelTask(handle)
      result_slot = @result_queue[task.handle]
      case result_slot.status
      when :UNSCHEDULED
        result_slot.status = :CANCELLED
      when :PENDING
        result_slot.status = :CANCELLED
        @timeout_queue.delete_if do |task|
          task.handle == handle
        end
      end
    end

    def _bg_dispatchTask(task)
      return if !@running
      result_slot = @result_queue[task.handle]
      return if result_slot.status != :PENDING

      result_slot.status = :RUNNING
      @executor.execute do
        result_slot.result = task.block.call
        result_slot.status = :FINISHED
      end
    end
  end
  
end
