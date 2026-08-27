# frozen_string_literal: true

require "optparse"
require "yaml"
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
      when "import" then import(argv)
      when "env" then env(argv)
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

    def run(argv)
      options = { request: nil, all: false }
      parser = OptionParser.new do |o|
        o.banner = "Usage: okapi run <collection.yaml> --env <environment.yaml> " \
                   "(--request NAME | --all) [--output FILE.har]"
        o.on("--env FILE", "Environment YAML file") { |v| options[:env] = v }
        o.on("--request NAME", "Run a single request by name") { |v| options[:request] = v }
        o.on("--all", "Run every request in the collection") { options[:all] = true }
        o.on("--output FILE", "Write results to a HAR file") { |v| options[:output] = v }
      end
      parser.parse!(argv)

      collection_path = argv.shift
      abort(parser.to_s) unless collection_path
      abort("error: --env is required") unless options[:env]
      abort("error: specify --request NAME or --all") unless options[:request] || options[:all]

      collection = Collection.load(collection_path)
      environment = Environment.load(options[:env])
      requests = options[:all] ? collection.requests : [collection.find(options[:request])]

      runner = Runner.new(environment)
      results = requests.map do |request|
        result = runner.execute(request)
        print_result(result)
        result
      end

      Har.write(options[:output], results) if options[:output]
    end

    def print_result(result)
      puts format(
        "%-6s %-40s -> %s %s (%.1fms)",
        result.method, result.name, result.status, result.status_message, result.time_ms
      )
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
      path = argv.shift
      abort("Usage: okapi env show <environment.yaml>") unless path

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
          run <collection.yaml> --env <environment.yaml> (--request NAME | --all) [--output FILE.har]
          list <collection.yaml>
          import postman <postman_collection.json> --output <collection.yaml>
          import openapi <spec.yaml|spec.json|URL> --output <collection.yaml> [--tag TAG]
          env show <environment.yaml>
      HELP
    end
  end
end
