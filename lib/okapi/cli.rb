# frozen_string_literal: true

require "optparse"
require "yaml"
require "json"
require "fileutils"

module Okapi
  class CLI
    def self.start(argv)
      new.start(argv)
    end

    def start(argv)
      command = argv.shift
      case command
      when "run" then run(argv)
      when "list" then list(argv)
      when "extract" then extract(argv)
      when "import" then import(argv)
      when "env" then env(argv)
      when "-v", "--version" then puts "okapi #{Okapi::VERSION}"
      when "-h", "--help", nil then print_help
      else
        warn "unknown command: #{command}"
        print_help
        exit 1
      end
    rescue Okapi::Error => e
      warn "error: #{e.message}"
      exit 1
    end

    private

    STDOUT_TARGETS = %w[stdout -].freeze
    DEFAULT_ENV_PATH = "envs/default.yaml"

    def run(argv)
      options = { request: nil, all: false }
      parser = OptionParser.new do |o|
        o.banner = "Usage: okapi run <collection.yaml> [--env <environment.yaml>] " \
                   "(--request NAME | --all) [--output FILE.har|stdout]"
        o.on(
          "--env FILE",
          "Environment YAML file (default: $OKAPI_ENV, or #{DEFAULT_ENV_PATH})"
        ) { |v| options[:env] = v }
        o.on("--request NAME", "Run a single request by name") { |v| options[:request] = v }
        o.on("--all", "Run every request in the collection") { options[:all] = true }
        o.on(
          "--output TARGET",
          "Write results to a HAR file, or log method/url/response to stdout ('stdout' or '-')"
        ) { |v| options[:output] = v }
      end
      parser.parse!(argv)

      collection_path = argv.shift
      abort(parser.to_s) unless collection_path
      env_path = resolve_env_path(options[:env])
      abort("error: no environment file given, $OKAPI_ENV not set, and #{DEFAULT_ENV_PATH} doesn't exist") unless env_path
      abort("error: specify --request NAME or --all") unless options[:request] || options[:all]

      collection = Collection.load(collection_path)
      environment = Environment.load(env_path)
      requests = options[:all] ? collection.requests : [collection.find(options[:request])]
      log_to_stdout = STDOUT_TARGETS.include?(options[:output])

      runner = Runner.new(environment)
      results = requests.map do |request|
        result = runner.execute(request)
        log_to_stdout ? log_result(result) : print_result(result)
        result
      end

      Har.write(options[:output], results) if options[:output] && !log_to_stdout
    end

    # Resolution order: explicit --env > $OKAPI_ENV > envs/default.yaml.
    # Lets a user set up a default environment once (or export OKAPI_ENV in
    # their shell profile) instead of typing --env on every invocation, while
    # --env still overrides either for a one-off run against another org.
    def resolve_env_path(explicit)
      return explicit if explicit
      return ENV["OKAPI_ENV"] if ENV["OKAPI_ENV"]
      return DEFAULT_ENV_PATH if File.exist?(DEFAULT_ENV_PATH)

      nil
    end

    def print_result(result)
      puts format(
        "%-6s %-40s -> %s %s (%.1fms)",
        result.method, result.name, result.status, result.status_message, result.time_ms
      )
    end

    # Logs the executed endpoint and its result for local troubleshooting.
    # Deliberately never prints request headers — that's where SSWS tokens
    # and other secrets pulled from the environment file live.
    def log_result(result)
      puts "=== #{result.name} ==="
      puts "#{result.method} #{result.url}"
      puts "-> #{result.status} #{result.status_message} (#{format("%.1f", result.time_ms)}ms)"
      puts pretty_body(result.response_body)
      puts
    end

    def pretty_body(body)
      return "(empty)" if body.to_s.empty?

      JSON.pretty_generate(JSON.parse(body))
    rescue JSON::ParserError
      body
    end

    def list(argv)
      path = argv.shift
      abort("Usage: okapi list <collection.yaml>") unless path

      collection = Collection.load(path)
      puts "#{collection.name} (#{collection.requests.size} request(s))"
      puts collection.description if collection.description
      collection.requests.each do |request|
        puts format("  %-6s %-30s %s", request.method, request.name, request.url)
      end
    end

    # Pulls one request out of a shared collection (headers/query already
    # merged in — see Request#to_h) into its own standalone collection file.
    # Editing body/query on a request that lives in a big generated
    # collection (e.g. collections/okta_management/user.yaml) means editing
    # a file shared by every other request in that tag; extracting first
    # gives a throwaway file that's safe to hack on freely.
    def extract(argv)
      options = {}
      parser = OptionParser.new do |o|
        o.banner = "Usage: okapi extract <collection.yaml> --request NAME --output <file.yaml>"
        o.on("--request NAME", "Request to extract") { |v| options[:request] = v }
        o.on("--output FILE", "Write the standalone request to FILE") { |v| options[:output] = v }
      end
      parser.parse!(argv)

      collection_path = argv.shift
      abort(parser.to_s) unless collection_path && options[:request] && options[:output]

      collection = Collection.load(collection_path)
      request = collection.find(options[:request])
      standalone = { "name" => request.name, "requests" => [request.to_h] }
      File.write(options[:output], YAML.dump(standalone))
      puts "Extracted \"#{request.name}\" to #{options[:output]}"
    end

    def import(argv)
      subcommand = argv.shift
      case subcommand
      when "postman" then import_postman(argv)
      when "openapi" then import_openapi(argv)
      else
        abort("unknown import type: #{subcommand.inspect}")
      end
    end

    def import_postman(argv)
      options = {}
      parser = OptionParser.new do |o|
        o.banner = "Usage: okapi import postman <postman_collection.json> --output <collection.yaml>"
        o.on("--output FILE", "Write the imported collection to FILE") { |v| options[:output] = v }
      end
      parser.parse!(argv)

      input_path = argv.shift
      abort(parser.to_s) unless input_path && options[:output]

      collection = Importer::Postman.import(input_path)
      File.write(options[:output], YAML.dump(collection))
      puts "Imported #{collection["requests"].size} request(s) to #{options[:output]}"
    end

    def import_openapi(argv)
      options = {}
      parser = OptionParser.new do |o|
        o.banner = "Usage: okapi import openapi <spec.yaml|spec.json|URL> --output <collection.yaml> [--tag TAG]\n" \
                   "   or: okapi import openapi <spec.yaml|spec.json|URL> --output-dir <dir>  " \
                   "(one collection per API tag/resource)"
        o.on("--output FILE", "Write a single merged collection to FILE") { |v| options[:output] = v }
        o.on("--output-dir DIR", "Write one collection per tag into DIR") { |v| options[:output_dir] = v }
        o.on("--tag TAG", "With --output, only import operations tagged with TAG") { |v| options[:tag] = v }
      end
      parser.parse!(argv)

      source = argv.shift
      abort(parser.to_s) unless source && (options[:output] || options[:output_dir])

      if options[:output_dir]
        import_openapi_by_tag(source, options[:output_dir])
      else
        collection = Importer::OpenApi.import(source, tag: options[:tag])
        File.write(options[:output], YAML.dump(collection))
        puts "Imported #{collection["requests"].size} request(s) to #{options[:output]}"
      end
    end

    def import_openapi_by_tag(source, dir)
      FileUtils.mkdir_p(dir)
      grouped = Importer::OpenApi.import_grouped_by_tag(source)
      grouped.each do |tag, collection|
        File.write(File.join(dir, "#{slugify(tag)}.yaml"), YAML.dump(collection))
      end

      total = grouped.values.sum { |c| c["requests"].size }
      puts "Imported #{total} request(s) across #{grouped.size} file(s) into #{dir}/"
    end

    def slugify(name)
      name.gsub(/[^a-zA-Z0-9]+/, "_").gsub(/\A_+|_+\z/, "").downcase
    end

    def env(argv)
      subcommand = argv.shift
      case subcommand
      when "show" then env_show(argv)
      else
        abort("unknown env subcommand: #{subcommand.inspect}")
      end
    end

    def env_show(argv)
      path = resolve_env_path(argv.shift)
      unless path
        abort("error: no environment file given, $OKAPI_ENV not set, and #{DEFAULT_ENV_PATH} doesn't exist\n" \
              "Usage: okapi env show [environment.yaml]")
      end

      environment = Environment.load(path)
      puts "#{environment.name} (#{path})"
      environment.variables.each do |key, value|
        puts "  #{key} = #{value}"
      end
    end

    def print_help
      puts <<~HELP
        Usage: okapi <command> [options]

        Commands:
          run <collection.yaml> [--env <environment.yaml>] (--request NAME | --all) [--output FILE.har|stdout]
          list <collection.yaml>
          extract <collection.yaml> --request NAME --output <file.yaml>
          import postman <postman_collection.json> --output <collection.yaml>
          import openapi <spec.yaml|spec.json|URL> --output <collection.yaml> [--tag TAG]
          env show [environment.yaml]
          -v, --version

        Environment file resolution (for `run` and `env show`):
          --env FILE > $OKAPI_ENV > #{DEFAULT_ENV_PATH}
      HELP
    end
  end
end
