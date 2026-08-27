# frozen_string_literal: true

require "yaml"

module Okapi
  class Collection
    attr_reader :name, :description, :requests, :path

    def self.load(path)
      data = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true) || {}
      requests = (data["requests"] || []).map { |r| Request.new(r) }
      new(
        name: data["name"] || File.basename(path, ".*"),
        description: data["description"],
        requests: requests,
        path: path
      )
    end

    def initialize(name:, requests:, description: nil, path: nil)
      @name = name
      @description = description
      @requests = requests
      @path = path
    end

    def find(name)
      requests.find { |r| r.name == name } ||
        raise(Okapi::RequestNotFoundError, name)
    end
  end

  class Request
    attr_reader :name, :method, :url, :headers, :query, :body

    def initialize(attrs)
      @name = attrs["name"]
      @method = (attrs["method"] || "GET").to_s.upcase
      @url = attrs["url"]
      @headers = attrs["headers"] || {}
      @query = attrs["query"] || {}
      @body = attrs["body"]
    end
  end
end
