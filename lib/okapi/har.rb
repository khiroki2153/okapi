# frozen_string_literal: true

require "json"
require "time"
require "uri"

module Okapi
  # Builds a HAR 1.2 log from a list of Runner::Result. Response bodies are
  # always stored as plain strings (content.text), so JSON responses never
  # get double-encoded ("JSON on JSON") inside the HAR file.
  module Har
    SPEC_VERSION = "1.2"

    module_function

    def build(results)
      {
        "log" => {
          "version" => SPEC_VERSION,
          "creator" => { "name" => "okapi", "version" => Okapi::VERSION },
          "entries" => results.map { |result| entry_for(result) }
        }
      }
    end

    def write(path, results)
      File.write(path, JSON.pretty_generate(build(results)))
    end

    def entry_for(result)
      uri = URI.parse(result.url)
      {
        "startedDateTime" => result.started_at.iso8601(3),
        "time" => result.time_ms,
        "request" => {
          "method" => result.method,
          "url" => result.url,
          "httpVersion" => "HTTP/1.1",
          "headers" => header_list(result.headers),
          "queryString" => query_list(uri),
          "postData" => post_data(result),
          "headersSize" => -1,
          "bodySize" => result.body.to_s.bytesize
        },
        "response" => {
          "status" => result.status,
          "statusText" => result.status_message.to_s,
          "httpVersion" => "HTTP/1.1",
          "headers" => header_list(result.response_headers),
          "content" => {
            "size" => result.response_body.to_s.bytesize,
            "mimeType" => result.response_headers["content-type"].to_s,
            "text" => result.response_body.to_s
          },
          "redirectURL" => result.response_headers["location"].to_s,
          "headersSize" => -1,
          "bodySize" => result.response_body.to_s.bytesize
        },
        "cache" => {},
        "timings" => { "send" => 0, "wait" => result.time_ms, "receive" => 0 }
      }
    end

    def header_list(headers)
      (headers || {}).map { |name, value| { "name" => name.to_s, "value" => value.to_s } }
    end

    def query_list(uri)
      return [] unless uri.query

      URI.decode_www_form(uri.query).map { |name, value| { "name" => name, "value" => value } }
    end

    def post_data(result)
      return nil if result.body.to_s.empty?

      {
        "mimeType" => (result.headers || {})["Content-Type"].to_s,
        "text" => result.body.to_s
      }
    end
  end
end
