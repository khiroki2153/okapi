# frozen_string_literal: true

require_relative "../spec_helper"

describe Okapi::Importer::Postman do
  let(:collection) { Okapi::Importer::Postman.import(fixture_path("postman_collection.json")) }

  it "flattens folders into a single requests list, prefixing the folder name" do
    _(collection["name"]).must_equal "Okta Users API"
    names = collection["requests"].map { |r| r["name"] }
    _(names).must_equal ["Users / List Users", "Users / Create User", "Users / Create User Form"]
  end

  it "converts headers and skips disabled ones" do
    request = collection["requests"].first
    _(request["headers"]).must_equal("Authorization" => "SSWS {{apiToken}}")
  end

  it "converts url and query params, skipping disabled ones" do
    request = collection["requests"].first
    _(request["url"]).must_equal "{{baseUrl}}/api/v1/users"
    _(request["query"]).must_equal("limit" => "25")
  end

  it "converts a raw JSON body" do
    request = collection["requests"][1]
    _(request["body"]).must_equal("type" => "json", "content" => { "profile" => { "firstName" => "John" } })
  end

  it "converts a urlencoded body to form-data, skipping disabled params" do
    request = collection["requests"][2]
    _(request["body"]).must_equal("type" => "form-data", "content" => { "firstName" => "John" })
  end
end
