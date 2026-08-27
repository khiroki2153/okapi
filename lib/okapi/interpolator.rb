# frozen_string_literal: true

module Okapi
  # Substitutes "{{variable}}" placeholders with values from an environment's
  # variables hash. Walks Strings/Hashes/Arrays recursively so it can be
  # applied uniformly to a request's url, headers, query, and body.
  module Interpolator
    PLACEHOLDER = /\{\{\s*([^{}\s]+)\s*\}\}/

    module_function

    def apply(value, variables)
      case value
      when String
        interpolate_string(value, variables)
      when Hash
        value.each_with_object({}) { |(k, v), h| h[k] = apply(v, variables) }
      when Array
        value.map { |v| apply(v, variables) }
      else
        value
      end
    end

    def interpolate_string(string, variables)
      string.gsub(PLACEHOLDER) do
        name = Regexp.last_match(1)
        unless variables.key?(name)
          raise Okapi::MissingVariableError, name
        end

        variables[name].to_s
      end
    end
  end
end
