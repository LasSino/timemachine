# frozen_string_literal: true

module TimeMachine
  #
  # Executors contains executor interface and implementations.
  # An executor is where a timed-up task is actually executed,
  # thus decoupled with the scheduler.
  #
  module Executors
    #
    # The base class (interface) for a executor.
    #
    class Executor
      def execute(&block)
        raise NotImplementedError
      end
    end
  end
end
