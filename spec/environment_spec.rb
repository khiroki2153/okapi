# frozen_string_literal: true

require_relative "spec_helper"

describe Okapi::Environment do
  it "loads name and variables from a YAML file" do
    environment = Okapi::Environment.load(fixture_path("sandbox.yaml"))
    _(environment.name).must_equal "Sandbox"
    _(environment.variables).must_equal(
      "baseUrl" => "https://dev-12345678.okta.com",
      "apiToken" => "00xxxxxxxxxxxxxxxxxxxxx"
    )
  end
end
