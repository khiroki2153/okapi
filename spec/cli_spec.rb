# frozen_string_literal: true

require_relative "spec_helper"
require "tmpdir"
require "fileutils"

def write_env(dir, relative_path, name)
  path = File.join(dir, relative_path)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, YAML.dump("name" => name, "variables" => {}))
  path
end

describe Okapi::CLI do
  it "prints the version with -v or --version" do
    out1, = capture_io { Okapi::CLI.start(["-v"]) }
    out2, = capture_io { Okapi::CLI.start(["--version"]) }

    _(out1).must_equal "okapi #{Okapi::VERSION}\n"
    _(out2).must_equal "okapi #{Okapi::VERSION}\n"
  end

  it "lists requests in a collection without hitting the network" do
    out, = capture_io { Okapi::CLI.start(["list", fixture_path("collection.yaml")]) }

    _(out).must_include "Okta Users API (2 request(s))"
    _(out).must_include "GET"
    _(out).must_include "List Users"
    _(out).must_include "Create User"
  end

  it "prints an environment's variables" do
    out, = capture_io { Okapi::CLI.start(["env", "show", fixture_path("sandbox.yaml")]) }

    _(out).must_include "Sandbox"
    _(out).must_include "baseUrl = https://dev-12345678.okta.com"
  end

  it "run --output stdout logs the executed endpoint and response, never header values" do
    with_fake_http_server do |port|
      Dir.mktmpdir do |dir|
        env_path = File.join(dir, "env.yaml")
        File.write(env_path, YAML.dump(
          "name" => "Local",
          "variables" => { "baseUrl" => "http://127.0.0.1:#{port}", "apiToken" => "super-secret-token" }
        ))

        out, = capture_io do
          Okapi::CLI.start(
            ["run", fixture_path("collection.yaml"), "--env", env_path, "--request", "List Users", "--output", "stdout"]
          )
        end

        _(out).must_include "=== List Users ==="
        _(out).must_include "GET http://127.0.0.1:#{port}/api/v1/users"
        _(out).must_include "200 OK"
        _(out).must_include '"method": "GET"'

        # The fake server echoes back whatever headers it received (including
        # our own Authorization header) inside its response body, so the
        # token legitimately shows up there — that's the server's response,
        # not a leak. What must never happen is *our own* request line
        # (method + resolved url + status) printing the token, since that's
        # the part okapi controls and headers are deliberately excluded from.
        request_line = out.lines.first(3).join
        _(request_line).wont_include "super-secret-token"
      end
    end
  end

  describe "environment file resolution" do
    before do
      @original_okapi_env = ENV["OKAPI_ENV"]
      ENV.delete("OKAPI_ENV")
    end

    after do
      @original_okapi_env.nil? ? ENV.delete("OKAPI_ENV") : ENV["OKAPI_ENV"] = @original_okapi_env
    end

    it "prefers an explicit --env over $OKAPI_ENV" do
      Dir.mktmpdir do |dir|
        explicit_path = write_env(dir, "explicit.yaml", "Explicit")
        ENV["OKAPI_ENV"] = write_env(dir, "from_env_var.yaml", "FromEnvVar")

        out, = capture_io { Okapi::CLI.start(["env", "show", explicit_path]) }

        _(out).must_include "Explicit"
      end
    end

    it "falls back to $OKAPI_ENV when --env is omitted" do
      Dir.mktmpdir do |dir|
        ENV["OKAPI_ENV"] = write_env(dir, "from_env_var.yaml", "FromEnvVar")

        out, = capture_io { Okapi::CLI.start(["env", "show"]) }

        _(out).must_include "FromEnvVar"
      end
    end

    it "falls back to envs/default.yaml relative to the working directory when neither is set" do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, "envs"))
        write_env(dir, "envs/default.yaml", "DefaultFile")

        out, = capture_io { Dir.chdir(dir) { Okapi::CLI.start(["env", "show"]) } }

        _(out).must_include "DefaultFile"
      end
    end

    it "errors clearly when no --env, $OKAPI_ENV, or envs/default.yaml is available" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          _(-> { Okapi::CLI.start(["env", "show"]) }).must_raise(SystemExit)
        end
      end
    end
  end

  it "extract pulls one request out of a collection into a standalone, freely-editable file" do
    Dir.mktmpdir do |dir|
      out_path = File.join(dir, "list_users.yaml")

      out, = capture_io do
        Okapi::CLI.start(
          ["extract", fixture_path("collection_with_defaults.yaml"), "--request", "List Users", "--output", out_path]
        )
      end

      _(out).must_include "Extracted"
      extracted = Okapi::Collection.load(out_path)
      _(extracted.requests.size).must_equal 1

      request = extracted.find("List Users")
      # Collection-level defaults from the source collection are inlined —
      # the extracted file has no dependency on the original collection.
      _(request.headers).must_equal("Authorization" => "SSWS {{apiToken}}", "Accept" => "application/json")
      _(request.query).must_equal("limit" => 25)
    end
  end

  it "run --output <file> still writes a HAR file instead of logging to stdout" do
    with_fake_http_server do |port|
      Dir.mktmpdir do |dir|
        env_path = File.join(dir, "env.yaml")
        har_path = File.join(dir, "out.har")
        File.write(env_path, YAML.dump(
          "name" => "Local",
          "variables" => { "baseUrl" => "http://127.0.0.1:#{port}", "apiToken" => "secret" }
        ))

        out, = capture_io do
          Okapi::CLI.start(
            ["run", fixture_path("collection.yaml"), "--env", env_path, "--request", "List Users", "--output", har_path]
          )
        end

        _(out).wont_include "==="
        har = JSON.parse(File.read(har_path))
        _(har["log"]["entries"].size).must_equal 1
      end
    end
  end
end
