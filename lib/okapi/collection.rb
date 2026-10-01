# frozen_string_literal: true

require "yaml"

module Okapi
  class Collection
    attr_reader :name, :description, :headers, :query, :requests, :path

    def self.load(path)
      data = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true) || {}
      headers = data["headers"] || {}
      query = data["query"] || {}
      requests = (data["requests"] || []).map { |r| Request.new(r, headers, query) }

      new(
        name: data["name"] || File.basename(path, ".*"),
        description: data["description"],
        headers: headers,
        query: query,
        requests: requests,
        path: path
      )
    end

    def initialize(name:, requests:, description: nil, headers: {}, query: {}, path: nil)
      @name = name
      @description = description
      @headers = headers
      @query = query
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

    # default_headers/default_query come from the collection this request
    # was loaded under (see Collection.load) — a request's own headers/query
    # win on key conflicts, everything else is inherited, so a shared
    # Authorization header only needs to be written once per collection
    # instead of once per request.
    def initialize(attrs, default_headers = {}, default_query = {})
      @name = attrs["name"]
      @method = (attrs["method"] || "GET").to_s.upcase
      @url = attrs["url"]
      @headers = default_headers.merge(attrs["headers"] || {})
      @query = default_query.merge(attrs["query"] || {})
      @body = attrs["body"]
    end

    # Fully-resolved representation (collection defaults already merged in)
    # suitable for dumping as a standalone request — see `okapi extract`,
    # which uses this to pull one request out of a shared collection into
    # its own freely-editable file without having to touch the original.
    def to_h
      {
        "name" => name,
        "method" => method,
        "url" => url,
        "headers" => headers,
        "query" => query,
        "body" => body
      }.reject { |_, v| v.nil? || v == {} }
    end
  end
end
