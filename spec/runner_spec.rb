# frozen_string_literal: true

require_relative "spec_helper"
require "socket"
require "json"

describe Okapi::Runner do
  before do
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve(@server) }
  end

  after do
    @server.close
    @thread.kill
  end

  def serve(server)
    loop do
      client = server.accept
      handle(client)
    end
  rescue IOError, Errno::EBADF
    nil
  end

  def handle(client)
    request_line = client.gets
    return unless request_line

    method, path, = request_line.split(" ")
    headers = {}
    while (line = client.gets) && line.chomp != ""
      key, value = line.split(":", 2)
      headers[key.strip.downcase] = value.strip
    end
    body = headers["content-length"] ? client.read(headers["content-length"].to_i) : ""

    payload = JSON.generate("method" => method, "path" => path, "headers" => headers, "body" => body)
    client.write(
      "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" \
      "Content-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}"
    )
  ensure
    client&.close
  end

  it "interpolates and executes a GET request with query params" do
    environment = Okapi::Environment.new(
      name: "test", variables: { "host" => "127.0.0.1:#{@port}", "token" => "secret" }
    )
    request = Okapi::Request.new(
      "name" => "List Users",
      "method" => "GET",
      "url" => "http://{{host}}/api/v1/users",
      "headers" => { "Authorization" => "SSWS {{token}}" },
      "query" => { "limit" => 25 }
    )

    result = Okapi::Runner.new(environment).execute(request)

    _(result.status).must_equal 200
    echoed = JSON.parse(result.response_body)
    _(echoed["method"]).must_equal "GET"
    _(echoed["path"]).must_equal "/api/v1/users?limit=25"
    _(echoed["headers"]["authorization"]).must_equal "SSWS secret"
  end

  it "sends a JSON body for POST requests and defaults Content-Type" do
    environment = Okapi::Environment.new(name: "test", variables: { "host" => "127.0.0.1:#{@port}" })
    request = Okapi::Request.new(
      "name" => "Create User",
      "method" => "POST",
      "url" => "http://{{host}}/api/v1/users",
      "body" => { "type" => "json", "content" => { "email" => "john@example.com" } }
    )

    result = Okapi::Runner.new(environment).execute(request)

    echoed = JSON.parse(result.response_body)
    _(echoed["method"]).must_equal "POST"
    _(JSON.parse(echoed["body"])).must_equal("email" => "john@example.com")
    _(echoed["headers"]["content-type"]).must_equal "application/json"
  end

  it "raises MissingVariableError when an environment variable is absent" do
    environment = Okapi::Environment.new(name: "test", variables: {})
    request = Okapi::Request.new("name" => "X", "method" => "GET", "url" => "http://{{host}}/")

    _(-> { Okapi::Runner.new(environment).execute(request) }).must_raise(Okapi::MissingVariableError)
  end
end
