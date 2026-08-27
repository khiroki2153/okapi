# frozen_string_literal: true

require_relative "../spec_helper"

describe Okapi::Importer::OpenApi do
  let(:collection) { Okapi::Importer::OpenApi.import(fixture_path("openapi_spec.yaml")) }

  it "uses the spec's info.title and description" do
    _(collection["name"]).must_equal "Sample API"
    _(collection["description"]).must_equal "A tiny OpenAPI 3 document for testing the importer"
  end

  it "prefixes request names with the operation's first tag" do
    names = collection["requests"].map { |r| r["name"] }
    _(names).must_equal [
      "User / List all users",
      "User / Create a user",
      "User / Get a user",
      "User / Deactivate a user",
      "Group / List groups",
      "Group / Create a group"
    ]
  end

  it "templates {param} path segments into {{param}} and prefixes baseUrl" do
    request = collection["requests"].find { |r| r["name"] == "User / Get a user" }
    _(request["url"]).must_equal "{{baseUrl}}/api/v1/users/{{userId}}"
  end

  it "resolves a requestBody example behind a $ref" do
    request = collection["requests"].find { |r| r["name"] == "User / Create a user" }
    _(request["body"]).must_equal(
      "type" => "json",
      "content" => { "profile" => { "firstName" => "John", "lastName" => "Doe" } }
    )
    _(request["headers"]["Content-Type"]).must_equal "application/json"
  end

  it "resolves an inline requestBody example" do
    request = collection["requests"].find { |r| r["name"] == "User / Deactivate a user" }
    _(request["body"]).must_equal("type" => "json", "content" => { "sendEmail" => false })
  end

  it "omits body and Content-Type for requests without a requestBody" do
    request = collection["requests"].find { |r| r["name"] == "User / List all users" }
    _(request["body"]).must_be_nil
    _(request["headers"]).must_equal("Authorization" => "SSWS {{apiToken}}", "Accept" => "application/json")
  end

  it "filters by tag when requested" do
    filtered = Okapi::Importer::OpenApi.import(fixture_path("openapi_spec.yaml"), tag: "NoSuchTag")
    _(filtered["requests"]).must_equal []
  end

  it "groups operations into one collection per tag" do
    grouped = Okapi::Importer::OpenApi.import_grouped_by_tag(fixture_path("openapi_spec.yaml"))

    _(grouped.keys).must_equal %w[User Group]
    _(grouped["User"]["name"]).must_equal "User"
    _(grouped["User"]["requests"].size).must_equal 4
    _(grouped["Group"]["requests"].map { |r| r["name"] }).must_equal ["Group / List groups", "Group / Create a group"]
  end

  it "gives every generated request its own header objects, never aliased" do
    dumped = YAML.dump(collection)

    _(dumped).wont_match(/&\d/)
    _(dumped).wont_match(/\*\d/)
  end

  it "doesn't alias a requestBody example reused via $ref by two different operations" do
    dumped = YAML.dump(collection)

    _(dumped).wont_match(/&\d/)
    _(dumped).wont_match(/\*\d/)

    user_body = collection["requests"].find { |r| r["name"] == "User / Create a user" }["body"]
    group_body = collection["requests"].find { |r| r["name"] == "Group / Create a group" }["body"]
    _(user_body["content"]).must_equal(group_body["content"])
    refute_same(user_body["content"], group_body["content"])
  end
end
