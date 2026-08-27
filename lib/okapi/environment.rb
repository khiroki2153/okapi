# frozen_string_literal: true

require "yaml"

module Okapi
  class Environment
    attr_reader :name, :variables, :path

    def self.load(path)
      data = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true) || {}
      new(
        name: data["name"] || File.basename(path, ".*"),
        variables: data["variables"] || {},
        path: path
      )
    end

    def initialize(name:, variables:, path: nil)
      @name = name
      @variables = variables
      @path = path
    end
  end
end
