# frozen_string_literal: true

module Okapi
  class Error < StandardError; end

  class MissingVariableError < Error
    def initialize(name)
      super("missing variable: #{name}")
    end
  end

  class RequestNotFoundError < Error
    def initialize(name)
      super("request not found: #{name}")
    end
  end

  class UnsupportedMethodError < Error
    def initialize(method)
      super("unsupported HTTP method: #{method}")
    end
  end
end
