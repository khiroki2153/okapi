# frozen_string_literal: true

require "json"

module Okapi
  module Importer
    # One-way importer for Postman Collection v2.1 JSON exports (including
    # Okta's published Postman collections) into okapi's native YAML format.
    module Postman
      module_function

      def import(path)
        data = JSON.parse(File.read(path))
        deep_dup(
          {
            "name" => data.dig("info", "name") || File.basename(path, ".*"),
            "description" => data.dig("info", "description"),
            "requests" => flatten_items(data["item"] || [])
          }
        )
      end

      def flatten_items(items, prefix = nil)
        items.flat_map do |item|
          name = [prefix, item["name"]].compact.join(" / ")
          if item["item"]
            flatten_items(item["item"], name)
          else
            [convert_request(name, item["request"] || {})]
          end
        end
      end

      def convert_request(name, request)
        {
          "name" => name,
          "method" => (request["method"] || "GET").to_s.upcase,
          "url" => request_url(request["url"]),
          "headers" => convert_headers(request["header"]),
          "query" => convert_query(request["url"]),
          "body" => convert_body(request["body"])
        }.compact
      end

      def request_url(url)
        return url if url.is_a?(String)
        return nil unless url.is_a?(Hash)

        url["raw"]&.split("?")&.first
      end

      def convert_headers(headers)
        return {} unless headers.is_a?(Array)

        headers.each_with_object({}) do |header, hash|
          next if header["disabled"]

          hash[header["key"]] = header["value"]
        end
      end

      def convert_query(url)
        return {} unless url.is_a?(Hash) && url["query"].is_a?(Array)

        url["query"].each_with_object({}) do |param, hash|
          next if param["disabled"]

          hash[param["key"]] = param["value"]
        end
      end

      def convert_body(body)
        return nil unless body.is_a?(Hash)

        case body["mode"]
        when "raw"
          language = body.dig("options", "raw", "language")
          parsed = parse_json(body["raw"])
          if language == "json" || parsed
            { "type" => "json", "content" => parsed || body["raw"] }
          else
            { "type" => "raw", "content" => body["raw"] }
          end
        when "urlencoded"
          content = (body["urlencoded"] || []).each_with_object({}) do |param, hash|
            next if param["disabled"]

            hash[param["key"]] = param["value"]
          end
          { "type" => "form-data", "content" => content }
        end
      end

      def parse_json(raw)
        return nil if raw.nil? || raw.strip.empty?

        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end

      # See Okapi::Importer::OpenApi#deep_dup: without this, frozen_string_literal
      # makes repeated literals (e.g. "type" => "json") share one object, so
      # YAML.dump would alias them and hand-editing one request could silently
      # mutate another. Marshal round-tripping does NOT fix this — it faithfully
      # preserves shared object identity — so this walks and copies explicitly.
      def deep_dup(value)
        case value
        when Hash
          value.each_with_object({}) { |(k, v), h| h[deep_dup(k)] = deep_dup(v) }
        when Array
          value.map { |v| deep_dup(v) }
        when String
          value.dup
        else
          value
        end
      end
    end
  end
end
