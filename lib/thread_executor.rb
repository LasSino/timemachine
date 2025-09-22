# frozen_string_literal: true

require 'executor'

module TimeMachine
  module Executors
    #
    # ThreadExecutor is currently the only implementation of Executor.
    # It executes the task in a background thread, so slow tasks will not
    # block the scheduler.
    #
    class ThreadExecutor < Executor
      def execute(&block)
        Thread.new(&block)
      end
    end
  end
end