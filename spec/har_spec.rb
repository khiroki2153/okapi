# frozen_string_literal: true

require_relative "spec_helper"
require "tmpdir"
require "time"

describe Okapi::Har do
  let(:result) do
    Okapi::Runner::Result.new(
      name: "List Users",
      method: "GET",
      url: "https://example.okta.com/api/v1/users?limit=25",
      headers: { "Authorization" => "SSWS secret" },
      body: nil,
      status: 200,
      status_message: "OK",
      response_headers: { "content-type" => "application/json" },
      response_body: '{"id":"1"}',
      started_at: Time.parse("2026-01-01T00:00:00Z"),
      time_ms: 12.3
    )
  end

  it "builds a HAR 1.2 log with one entry per result" do
    har = Okapi::Har.build([result])

    _(har["log"]["version"]).must_equal "1.2"
    entry = har["log"]["entries"].first
    _(entry["request"]["method"]).must_equal "GET"
    _(entry["request"]["queryString"]).must_equal [{ "name" => "limit", "value" => "25" }]
    _(entry["response"]["status"]).must_equal 200
  end

  it "stores the response body as a plain string, never re-parsed JSON" do
    har = Okapi::Har.build([result])
    text = har["log"]["entries"].first["response"]["content"]["text"]

    _(text).must_be_kind_of String
    _(text).must_equal '{"id":"1"}'
  end

  it "writes a parseable JSON file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "out.har")
      Okapi::Har.write(path, [result])

      parsed = JSON.parse(File.read(path))
      _(parsed["log"]["entries"].size).must_equal 1
    end
  end
end
