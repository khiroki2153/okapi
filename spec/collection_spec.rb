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
end
