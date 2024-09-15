# frozen_string_literal: true

module TimeMachine
  module Executors
    class Executor
      def execute(&block)
        raise NotImplementedError
      end
    end
  end
end
