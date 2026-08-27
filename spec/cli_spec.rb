# frozen_string_literal: true

require_relative "spec_helper"

describe Okapi::CLI do
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
end
