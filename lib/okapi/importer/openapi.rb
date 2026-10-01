# frozen_string_literal: true

require "yaml"
require "json"
require "net/http"
require "uri"

module Okapi
  module Importer
    # One-way importer for OpenAPI 3.x specs (JSON or YAML, local file or URL)
    # into okapi's native YAML collection format. Written against Okta's
    # officially published Management API spec
    # (https://github.com/okta/okta-management-openapi-spec), but only
    # relies on generic OpenAPI 3 structure ($ref, requestBody, examples),
    # so it isn't Okta-specific.
    module OpenApi
      HTTP_METHODS = %w[get put post delete options head patch].freeze
      # Every operation authenticates the same way, so this lives once at
      # collection level (see Okapi::Collection header inheritance) instead
      # of being repeated on every one of the hundreds of generated requests.
      COMMON_HEADERS = { "Authorization" => "SSWS {{apiToken}}", "Accept" => "application/json" }.freeze

      module_function

      def import(source, tag: nil)
        spec = load_spec(source)
        requests = []
        each_operation(spec) do |path, method, operation, tags|
          next if tag && !tags.include?(tag)

          requests << convert_operation(spec, path, method, operation, tags.first, name_prefix: true)
        end

        deep_dup(
          {
            "name" => spec.dig("info", "title") || "Imported API",
            "description" => spec.dig("info", "description"),
            "headers" => COMMON_HEADERS,
            "requests" => requests
          }.compact
        )
      end

      # Groups operations by their first tag (Okta's spec tags every
      # operation with its resource, e.g. "User", "Group", "Application" —
      # the same split developer.okta.com's own API reference uses), so a
      # sprawling spec becomes one right-sized collection per resource
      # instead of a single unwieldy file. Request names skip the tag prefix
      # `import` uses, since the containing file already says which tag
      # this is.
      def import_grouped_by_tag(source)
        spec = load_spec(source)
        grouped = Hash.new { |h, k| h[k] = [] }
        each_operation(spec) do |path, method, operation, tags|
          tag = tags.first || "Untagged"
          grouped[tag] << convert_operation(spec, path, method, operation, tag, name_prefix: false)
        end

        result = grouped.each_with_object({}) do |(tag, requests), out|
          out[tag] = { "name" => tag, "headers" => COMMON_HEADERS, "requests" => requests }
        end
        deep_dup(result)
      end

      def load_spec(source)
        raw = source.to_s.start_with?("http://", "https://") ? Net::HTTP.get(URI.parse(source)) : File.read(source)
        source.to_s.end_with?(".json") ? JSON.parse(raw) : YAML.safe_load(raw, permitted_classes: [Date, Time])
      end

      def each_operation(spec)
        (spec["paths"] || {}).each do |path, ops|
          HTTP_METHODS.each do |method|
            operation = ops[method]
            next unless operation

            yield path, method, operation, (operation["tags"] || [])
          end
        end
      end

      def convert_operation(spec, path, method, operation, tag, name_prefix:)
        spec_body = request_body_for(spec, operation)
        title = operation["summary"] || operation["operationId"] || "#{method.upcase} #{path}"

        {
          "name" => name_prefix ? [tag, title].compact.join(" / ") : title,
          "method" => method.upcase,
          "url" => "{{baseUrl}}#{templated_path(path)}",
          "headers" => spec_body ? { "Content-Type" => "application/json" } : nil,
          "body" => spec_body
        }.compact
      end

      def templated_path(path)
        path.gsub(/\{([^}]+)\}/) { "{{#{Regexp.last_match(1)}}}" }
      end

      def request_body_for(spec, operation)
        request_body = resolve_ref(spec, operation["requestBody"])
        return nil unless request_body

        content = request_body.dig("content", "application/json")
        return nil unless content

        example = content["example"] || first_example(spec, content["examples"])
        { "type" => "json", "content" => example || {} }
      end

      def first_example(spec, examples)
        return nil unless examples

        resolve_ref(spec, examples.values.first)&.dig("value")
      end

      def resolve_ref(spec, node)
        return node unless node.is_a?(Hash) && node["$ref"]

        node["$ref"].delete_prefix("#/").split("/").reduce(spec) { |acc, key| acc[key] }
      end

      # Two things make the same object show up more than once in the result:
      # Ruby's frozen_string_literal caches identical literals at a given
      # call site (every generated "Content-Type" header is the *same*
      # String instance), and multiple operations can resolve the exact same
      # $ref'd example object. Either way YAML.dump would emit anchors/aliases
      # for the shared object — which means hand-editing one imported
      # request could silently change another request sharing that anchor.
      # A real recursive copy (Marshal.dump/load preserves shared identity,
      # so it doesn't help here) gives every value its own identity so the
      # dumped YAML stays alias-free and safely editable.
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
