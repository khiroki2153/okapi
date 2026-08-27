# frozen_string_literal: true

require_relative "spec_helper"

describe Okapi::Interpolator do
  let(:variables) { { "baseUrl" => "https://example.okta.com", "limit" => 25 } }

  it "substitutes a placeholder in a string" do
    result = Okapi::Interpolator.apply("{{baseUrl}}/api/v1/users", variables)
    _(result).must_equal "https://example.okta.com/api/v1/users"
  end

  it "substitutes multiple placeholders" do
    result = Okapi::Interpolator.apply("{{baseUrl}}?limit={{limit}}", variables)
    _(result).must_equal "https://example.okta.com?limit=25"
  end

  it "recurses into nested hashes and arrays" do
    value = {
      "headers" => { "Authorization" => "SSWS {{baseUrl}}" },
      "list" => ["{{limit}}", "static"]
    }
    result = Okapi::Interpolator.apply(value, variables)
    _(result).must_equal(
      "headers" => { "Authorization" => "SSWS https://example.okta.com" },
      "list" => %w[25 static]
    )
  end

  it "leaves non-string, non-collection values untouched" do
    _(Okapi::Interpolator.apply(25, variables)).must_equal 25
    _(Okapi::Interpolator.apply(nil, variables)).must_be_nil
  end

  it "raises MissingVariableError for an unknown variable" do
    error = _(-> { Okapi::Interpolator.apply("{{missing}}", variables) }).must_raise(Okapi::MissingVariableError)
    _(error.message).must_include "missing"
  end
end
