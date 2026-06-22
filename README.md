# clowder-common-ruby

Ruby client library for reading [Clowder][clowder] operator configuration. Parses the JSON config
file written by Clowder into typed Ruby objects with convenience accessors for Kafka, database,
object storage, and other subsystems.

Based on `schema.json`, the corresponding Ruby classes are auto-generated in `types.rb`.

## Installation

Add the gem to your application's Gemfile:

```ruby
gem "clowder-common-ruby"
```

Then run:

```sh
bundle install
```

Or install directly:

```sh
gem install clowder-common-ruby
```

## Usage

The Clowder operator sets the `ACG_CONFIG` environment variable to the path of a JSON configuration
file on the pod filesystem. This library reads that file and exposes typed accessors for each
subsystem.

```ruby
require 'clowder-common-ruby'

@config ||= {}.tap do |options|
    # uses ENV['ACG_CONFIG'] or you can provide the path as a method param

  if ClowderCommonRuby::Config.clowder_enabled?
    config = ClowderCommonRuby::Config.load
    options["publicPort"]       = config.publicPort
    options["databaseHostname"] = config.database.hostname
    options["kafkaTopics"]      = config.kafka_topics
    # ...
  else
    options["publicPort"] = 3000
    options["databaseHostname"] = ENV['DATABASE_HOST']
  end
end
```

### Convenience Accessors

| Method | Returns |
|---|---|
| `config.kafka_topics` | Hash of `{ requestedName => TopicConfig }` |
| `config.kafka_servers` | Array of Kafka broker URLs |
| `config.object_buckets` | Hash of `{ requestedName => ObjectStoreBucket }` |
| `config.dependency_endpoints` | Nested hash `{ appName => { deploymentName => DependencyEndpoint } }` for public services |
| `config.private_dependency_endpoints` | Nested hash `{ appName => { deploymentName => PrivateDependencyEndpoint } }` for private services |

See [test.json][test-json] for all available configuration values.

### Usage in Rails

In Rails applications, require the engine to auto-load configuration into `Settings`:

```ruby
require 'clowder-common-ruby/engine'
```

The initializer runs at boot, converts the Clowder config into a Rails-friendly hash, and injects
it via `Settings.add_source!`. This requires the [config][config-gem] gem (`Settings` object) to be
available in the host application.

### Kafka Topics

Topics are structured as a hash `<requested_name> => <name>` where `requested_name` is equal to
the `topicName` key in your ClowdApp Custom Resource Definition (CRD) YAML.

If your Kafka is deployed in `local` or `app-interface` mode (see
[Clowder Kafka provider documentation][kafka-docs]), the `name` is equal to the `requested_name`.

## Development Setup

### Prerequisites

- Ruby (version pinned in `.ruby-version`, currently 3.4.9)
- Bundler

### Getting started

```sh
git clone https://github.com/RedHatInsights/clowder-common-ruby.git
cd clowder-common-ruby
bundle install
```

### Running tests

```sh
ACG_CONFIG="test.json" bundle exec rake spec
```

Or equivalently (since `spec` is the default Rake task):

```sh
ACG_CONFIG="test.json" bundle exec rake
```

### Manual smoke test

```sh
ACG_CONFIG="test.json" ruby lib/clowder-common-ruby/test.rb
```

This loads and prints the config file with parsed values.

### Regenerating types from upstream schema

To sync with the latest Clowder JSON Schema and regenerate `types.rb`:

```sh
./sync_config.sh
```

This downloads the schema from the [Clowder repository][clowder] and runs the code generator.

## Architecture

For internal design decisions, the code generation pipeline, and dependency points, see
[ARCHITECTURE.md][architecture].

## License

This project is licensed under the [Apache License 2.0][license].

[clowder]: https://github.com/RedHatInsights/clowder
[test-json]: ./test.json
[config-gem]: https://github.com/rubyconfig/config
[kafka-docs]: https://clowder-operator.readthedocs.io/en/latest/providers/kafka.html
[architecture]: ./ARCHITECTURE.md
[license]: ./LICENSE.txt
