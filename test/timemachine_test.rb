# frozen_string_literal: true

require "minitest/autorun"
require 'timemachine'

describe TimeMachine do 
  before(:all) do
    @time_machine = TimeMachine::TimeMachine.new
    @time_machine.start
  end

  after(:all) { @time_machine.stop }

  describe 'submittng task' do
    it 'can invoke the task correctly using TimeMachine#after' do
      counter = 0
      @time_machine.after(1) { counter += 1 }
      sleep(1.1)
      _(counter).must_equal 1
    end

    it 'can invoke the task correctly using TimeMachine#at' do
      timeup = Time.now + 1
      counter = 0
      @time_machine.at(timeup) { counter += 1 }
      sleep(1.1)
      _(counter).must_equal 1
    end

    it 'can invoke multiple tasks correctly using TimeMachine#after' do
      counter = 0
      500.times { @time_machine.after(1) { counter += 1 } }
      sleep(1.1)
      _(counter).must_equal 500
    end

    it 'can invoke multiple tasks correctly using TimeMachine#at' do
      timeup = Time.now + 1
      counter = 0
      500.times { @time_machine.at(timeup) { counter += 1 } }
      sleep(1.1)
      _(counter).must_equal 500
    end

    it 'can invoke multiple tasks correctly mixing TimeMachine#at and TimeMachine#after' do
      timeup = Time.now + 1
      counter = 0
      500.times { @time_machine.at(timeup) { counter += 1 } }
      500.times { @time_machine.after(1) { counter += 1 } }
      sleep(1.1)
      _(counter).must_equal 1000
    end

    it 'can invoke multiple tasks correctly mixing TimeMachine#at and TimeMachine#after at any time' do
      # Note: this is to ensure that the scheduler can run correctly after initial round of the loop.
      sleep(5)
      timeup = Time.now + 1
      counter = 0
      500.times { @time_machine.at(timeup) { counter += 1 } }
      500.times { @time_machine.after(1) { counter += 1 } }
      sleep(1.1)
      _(counter).must_equal 1000
    end

    it 'can query results asynchronously' do
      handlers = []
      100.times { handlers << @time_machine.after(1, record_result: true) { true } }
      sleep(1.1)
      handlers.all? { |h| _(@time_machine.pop_result(h).result).must_equal true}
    end
  end

  describe 'cancel task' do
    it 'can cancel tasks correctly' do
      counter = 0
      handlers = []
      500.times { handlers << @time_machine.after(1, record_result: false) { counter += 1 } }
      handlers.each { |h| @time_machine.cancel(h) }
      sleep(1.1)
      _(counter).must_equal 0
    end

    it 'can cancel tasks correctly at any time' do
      counter = 0
      handlers = []
      sleep(5)
      500.times { handlers << @time_machine.after(5, record_result: false) { counter += 1 } }
      sleep(3)
      handlers.each { |h| @time_machine.cancel(h) }
      sleep(3)
      _(counter).must_equal 0
    end

    it 'can cancel tasks correctly and record results' do
      counter = 0
      handlers = []
      sleep(5)
      500.times { handlers << @time_machine.after(5, record_result: true) { counter += 1 } }
      sleep(3)
      handlers.each { |h| @time_machine.cancel(h) }
      sleep(3)
      _(counter).must_equal 0
      handlers.all? { |h| _(@time_machine.pop_result(h).status).must_equal :CANCELLED}
    end
  end

  describe "mutli-threaded" do
    # Multi-thread tests.
    it 'can invoke multiple tasks correctly using multiple threads' do
      counter = 0
      500.times { Thread.new { @time_machine.after(1) { counter += 1 } } }
      sleep(1.1)
      _(counter).must_equal 500
    end

    it 'can query results asynchronously using multiple threads' do
      100.times { Thread.new do 
        h = @time_machine.after(1, record_result: true) { true }
        sleep(1.1)
        _(@time_machine.pop_result(h).result).must_equal true
      end }
      sleep(2)
    end

    it 'can cancel tasks correctly' do
      counter = 0
      100.times { Thread.new do 
        h = @time_machine.after(3, record_result: true) { true }
        sleep(1)
        @time_machine.cancel(h)
      end }
      sleep(4)
      _(counter).must_equal 0
    end
  end

  describe 'regarding memory leakage' do
    # Here are tests for memory leakage. Access control is voilated to check internal states.
    # Don't use these code in production.

    it 'will not leak memory' do
      counter = 0
      500.times { @time_machine.after(1, record_result: false) { counter += 1 } }
      sleep(1.1)
      _(counter).must_equal 500
      _(@time_machine.instance_variable_get(:@result_queue).size).must_equal 0
    end

    it 'can cancel tasks correctly at any time and won\'t leak memory' do
      counter = 0
      handlers = []
      sleep(5)
      500.times { handlers << @time_machine.after(5, record_result: false) { counter += 1 } }
      sleep(3)
      handlers.each { |h| @time_machine.cancel(h) }
      sleep(3)
      _(counter).must_equal 0
      _(@time_machine.instance_variable_get(:@result_queue).size).must_equal 0
    end
  end
end
