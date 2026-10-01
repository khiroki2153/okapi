# frozen_string_literal: true

require_relative "spec_helper"

describe Okapi::Collection do
  let(:collection) { Okapi::Collection.load(fixture_path("collection.yaml")) }

  it "loads collection metadata and requests" do
    _(collection.name).must_equal "Okta Users API"
    _(collection.requests.size).must_equal 2
  end

  it "parses each request's fields without interpolating them" do
    request = collection.find("List Users")
    _(request.method).must_equal "GET"
    _(request.url).must_equal "{{baseUrl}}/api/v1/users"
    _(request.headers["Authorization"]).must_equal "SSWS {{apiToken}}"
    _(request.query).must_equal("limit" => 25, "filter" => 'status eq "ACTIVE"')
  end

  it "parses a JSON body" do
    request = collection.find("Create User")
    _(request.body["type"]).must_equal "json"
    _(request.body["content"]["profile"]["firstName"]).must_equal "John"
  end

  it "raises RequestNotFoundError for an unknown request name" do
    _(-> { collection.find("Nope") }).must_raise(Okapi::RequestNotFoundError)
  end

  describe "collection-level headers/query inheritance" do
    let(:collection) { Okapi::Collection.load(fixture_path("collection_with_defaults.yaml")) }

    it "gives every request the collection's default headers and query" do
      request = collection.find("List Users")
      _(request.headers).must_equal("Authorization" => "SSWS {{apiToken}}", "Accept" => "application/json")
      _(request.query).must_equal("limit" => 25)
    end

    it "lets a request override a specific inherited key while keeping the rest" do
      request = collection.find("List Users Without Limit")
      _(request.query).must_equal("limit" => 5)
    end

    it "merges a request's own headers on top of the collection defaults" do
      request = collection.find("Create User")
      _(request.headers).must_equal(
        "Authorization" => "SSWS {{apiToken}}",
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      )
    end
  end
end
