# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "time"

module Okapi
  class Runner
    METHOD_CLASSES = {
      "GET" => Net::HTTP::Get,
      "POST" => Net::HTTP::Post,
      "PUT" => Net::HTTP::Put,
      "PATCH" => Net::HTTP::Patch,
      "DELETE" => Net::HTTP::Delete,
      "HEAD" => Net::HTTP::Head,
      "OPTIONS" => Net::HTTP::Options
    }.freeze

    Result = Struct.new(
      :name, :method, :url, :headers, :body,
      :status, :status_message, :response_headers, :response_body,
      :started_at, :time_ms,
      keyword_init: true
    )

    def initialize(environment)
      @environment = environment
    end

    def execute(request)
      variables = @environment.variables
      method = Interpolator.interpolate_string(request.method, variables)
      url = Interpolator.interpolate_string(request.url, variables)
      headers = Interpolator.apply(request.headers, variables)
      query = Interpolator.apply(request.query, variables)
      body = Interpolator.apply(request.body, variables)

      uri = build_uri(url, query)
      http_request = build_http_request(method, uri, headers, body)

      started_at = Time.now
      response = send_request(uri, http_request)
      time_ms = ((Time.now - started_at) * 1000).round(1)

      Result.new(
        name: request.name,
        method: method,
        url: uri.to_s,
        headers: headers,
        body: http_request.body,
        status: response.code.to_i,
        status_message: response.message,
        response_headers: response.each_header.to_h,
        response_body: response.body,
        started_at: started_at,
        time_ms: time_ms
      )
    end

    private

    def build_uri(url, query)
      uri = URI.parse(url)
      return uri if query.nil? || query.empty?

      existing = uri.query ? URI.decode_www_form(uri.query) : []
      merged = existing + query.map { |k, v| [k.to_s, v.to_s] }
      uri.query = URI.encode_www_form(merged)
      uri
    end

    def build_http_request(method, uri, headers, body)
      request_class = METHOD_CLASSES[method]
      http_request =
        if request_class
          request_class.new(uri)
        elsif method == "QUERY"
          Net::HTTPGenericRequest.new("QUERY", true, true, uri)
        else
          raise Okapi::UnsupportedMethodError, method
        end

      headers.each { |k, v| http_request[k.to_s] = v.to_s }
      apply_body(http_request, body)
      http_request
    end

    def apply_body(http_request, body)
      return if body.nil?

      type = (body["type"] || body[:type]).to_s
      content = body["content"] || body[:content]

      case type
      when "json"
        http_request["Content-Type"] ||= "application/json"
        http_request.body = JSON.generate(content)
      when "form-data", "form"
        http_request["Content-Type"] ||= "application/x-www-form-urlencoded"
        http_request.body = URI.encode_www_form(content)
      else
        http_request.body = content.to_s
      end
    end

    def send_request(uri, http_request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(http_request)
      end
    end
  end
end
