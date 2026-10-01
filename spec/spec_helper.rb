# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "okapi"
require "minitest/autorun"
require "minitest/spec"
require "socket"
require "json"

def fixture_path(*parts)
  File.join(__dir__, "fixtures", *parts)
end

# Starts a plain TCPServer that echoes back the method/path/headers/body of
# whatever it receives as a JSON body, yields the port it's listening on,
# then tears it down. Used instead of a mocking gem (none are installed) to
# exercise Runner/CLI against a real socket.
def with_fake_http_server
  server = TCPServer.new("127.0.0.1", 0)
  thread = Thread.new { serve_fake_http_requests(server) }

  yield server.addr[1]
ensure
  server.close
  thread.kill
end

def serve_fake_http_requests(server)
  loop do
    client = server.accept
    request_line = client.gets
    next unless request_line

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
    client.close
  end
rescue IOError, Errno::EBADF
  nil
end
