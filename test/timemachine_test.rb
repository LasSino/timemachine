# frozen_string_literal: true

require "minitest/autorun"
require 'timemachine'

describe TimeMachine do
  describe 'let\'s perform a sancheck!' do
    it 'must be ok!' do
      _(true).must_equal false
    end
  end
end