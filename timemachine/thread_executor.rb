# frozen_string_literal: true

require 'executor'

module TimeMachine
  module Executors
    class ThreadExecutor < Executor
      def execute(&block)
        Thread.new(&block)
      end
    end
  end
end