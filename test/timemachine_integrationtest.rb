# frozen_string_literal: true

require "minitest/autorun"
require 'timemachine'

describe TimeMachine do 
  before(:all) do
    @time_machine = TimeMachine::TimeMachine.new
    @time_machine.start
  end

  after(:all) { @time_machine.stop }

  describe 'integration test' do
    # Integration Test
    # This is rather slow, takes ~60s. 

    it 'can perform correctly in composite use cases' do
      counter = 0
      100.times { Thread.new do
        @time_machine.after(10, record_result: false) { counter += 1 }
      end }
      100.times { Thread.new do
        h = @time_machine.after(10, record_result: false) { counter += 1 }
        sleep(6)
        @time_machine.cancel(h)
      end }
      100.times { |i| Thread.new do
        h = @time_machine.after(8, record_result: true) {i}
        sleep(9)
        _(@time_machine.pop_result(h).result).must_equal i
      end }
      sleep 5
      100.times { Thread.new do
        @time_machine.after(10, record_result: false) { counter += 1 }
      end }
      100.times { Thread.new do
        h = @time_machine.after(10, record_result: false) { counter += 1 }
        sleep(6)
        @time_machine.cancel(h)
      end }
      100.times { |i| Thread.new do
        h = @time_machine.after(8, record_result: true) {i}
        sleep(9)
        _(@time_machine.pop_result(h).result).must_equal i
      end }
      sleep(15)
      _(counter).must_equal(200)
    end
  end
end
