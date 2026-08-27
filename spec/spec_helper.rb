# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "okapi"
require "minitest/autorun"
require "minitest/spec"

def fixture_path(*parts)
  File.join(__dir__, "fixtures", *parts)
end
