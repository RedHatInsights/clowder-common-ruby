# Architecture

Internal design decisions, dependency points, and key tradeoffs for `clowder-common-ruby`.

## Overview

This gem is a read-only configuration client. It parses JSON written by the [Clowder operator][clowder]
into typed Ruby objects. It never opens network connections to any downstream service — it only exposes
the configuration that other libraries use to connect.

## Module Structure

All runtime classes live under the `ClowderCommonRuby` module.

| Class | File | Role |
|---|---|---|
| `AppConfig` | `lib/clowder-common-ruby/types.rb` | Auto-generated root config object. Holds all subsystem configs as typed children. |
| `Config` | `lib/clowder-common-ruby/config.rb` | Hand-written public API. Extends `AppConfig` with `load`, `clowder_enabled?`, and convenience accessors. |
| `Engine` | `lib/clowder-common-ruby/engine.rb` | Optional `Rails::Engine` subclass with an isolated namespace. |
| `RailsConfig` | `lib/clowder-common-ruby/rails_config.rb` | Class-method adapter that converts Clowder config into a Rails-friendly hash for `Settings`. |

Sixteen additional type classes (`LoggingConfig`, `KafkaConfig`, `BrokerConfig`, `TopicConfig`,
`DatabaseConfig`, `ObjectStoreBucket`, `ObjectStoreConfig`, `FeatureFlagsConfig`, `InMemoryDBConfig`,
`DependencyEndpoint`, `PrivateDependencyEndpoint`, `PrometheusGatewayConfig`, `DependencyEndpointV2`,
`CloudWatchConfig`, `AppMetadata`, `DeploymentMetadata`) are auto-generated in `types.rb`. Each
mirrors a definition from the upstream [Clowder JSON Schema][schema].

## Data Flow

```text
ACG_CONFIG env var
      |
      v
Config.load  ──>  JSON.parse(File.read(path))
      |
      v
AppConfig.new(hash)  ──>  OpenStruct.new + recursive child construction
      |
      v
Convenience accessors (kafka_topics, kafka_servers, object_buckets,
dependency_endpoints, private_dependency_endpoints) build memoized
lookup hashes keyed by requestedName or app/deployment name.
```

1. The Clowder operator writes a JSON config file to the pod filesystem and sets `ACG_CONFIG` to its
   path.
2. `Config.clowder_enabled?` checks whether `ACG_CONFIG` is set and non-empty.
3. `Config.load` reads and parses the file, then delegates to `AppConfig#initialize`.
4. `AppConfig#initialize` calls `super` (OpenStruct) for scalar properties, then constructs typed
   child objects for every `$ref` and array property recursively.
5. Back in `Config#initialize`, five convenience accessors are called eagerly to front-load
   memoized lookup structures (e.g., `{ requestedName => TopicConfig }`).

## Code Generation Pipeline

`types.rb` is not hand-written. It is regenerated from the upstream Clowder JSON Schema:

1. **Sync** — `sync_config.sh` downloads `schema.json` from the [Clowder repository][clowder-schema]
   into `bin/schema.json`.
2. **Parse** — `bin/json_schema_ruby` invokes `RubyClassConverter` (`bin/ruby_class_converter.rb`),
   which reads the schema definitions.
3. **Generate** — For each schema definition, the converter emits:
   - A class declaration extending `OpenStruct`.
   - `attr_accessor` declarations for `$ref` and array properties only (scalars are handled by
     OpenStruct).
   - An `initialize` method that validates keys, warns on unknown keys, and recursively constructs
     typed children.
   - A `valid_keys` method listing expected property name symbols.
4. **Output** — The generated code is written to `lib/clowder-common-ruby/types.rb`.

The `schema.yml` CI workflow runs this pipeline daily on a cron schedule, bumps the patch version if
changes are detected, and opens a PR automatically.

## Rails Engine Integration

The Rails integration is opt-in and has three components:

1. **Engine** (`lib/clowder-common-ruby/engine.rb`) — declares an isolated namespace via
   `Rails::Engine`. Must be explicitly required by the host app.
2. **RailsConfig** (`lib/clowder-common-ruby/rails_config.rb`) — a class-method adapter that
   converts the Clowder config into a flat hash with entries for Kafka, Redis, PostgreSQL,
   CloudWatch, Unleash, and dependency endpoints.
3. **Initializer** (`config/initializers/0_clowder_rails.rb`) — runs at Rails boot. If
   `clowder_enabled?` and `Settings` is defined (from the `config` gem), it injects the converted
   config via `Settings.add_source!`. The `0_` filename prefix ensures it runs before other
   initializers that depend on `Settings`. It also handles TLS CA bundle concatenation for
   service-to-service communication.

## Design Decisions

### OpenStruct as base class

Every type class extends `OpenStruct`, providing free getter/setter methods for scalar properties
without explicit declarations. The tradeoff is performance overhead from `method_missing` and
deprecation warnings in Ruby 3.x+. The `ostruct` gem (~> 0.6.3) is depended on explicitly to
suppress Ruby 3.4+ bundled gem warnings.

### `attr_accessor` only for complex properties

The code generator emits `attr_accessor` only for `$ref` and array properties. These are assigned
via instance variables (`@name = ...`) in `initialize`, and without an explicit accessor the
OpenStruct getter would return `nil` since OpenStruct stores values in its internal table, not as
instance variables. Scalar properties skip this because `super` (OpenStruct) handles them directly.

### Soft key validation

Each class has a `valid_keys` method. Unknown keys produce a `warn` to stderr rather than raising
an exception. This is deliberately lenient — it allows the upstream schema to add new fields without
breaking older gem versions.

### Eager convenience accessor initialization

`Config#initialize` eagerly calls all five convenience methods (`kafka_topics`, `kafka_servers`,
`object_buckets`, `dependency_endpoints`, `private_dependency_endpoints`). These methods use `||=`
memoization, so the eager call front-loads construction of the lookup hashes at load time rather
than deferring to first access.

### camelCase property names preserved

Property names in generated classes match the JSON schema keys exactly (e.g., `requestedName`,
`secretAccessKey`). A `snakecase` helper exists in the converter but is unused. This keeps the Ruby
interface 1:1 with the JSON structure at the cost of non-idiomatic Ruby naming.

### No runtime dependencies in gemspec

The gemspec declares zero runtime dependencies. All dependencies (`rails`, `ostruct`,
`climate_control`) are listed only in the Gemfile. This means the gem is dependency-free when
installed via `gem install`, relying on the host app to provide `json` (stdlib) and any optional
Rails support.

## Dependency Points

The library is a config reader only. It exposes configuration for downstream services but never
connects to them directly.

| External System | Relationship |
|---|---|
| Clowder operator | Reads the JSON config file at the path in `ACG_CONFIG` |
| Kafka | Exposes broker URLs and topic mappings |
| PostgreSQL | Exposes database connection credentials |
| Redis (InMemoryDB) | Exposes connection URL and credentials |
| S3-compatible object store | Exposes bucket configs with access keys |
| Unleash (feature flags) | Exposes server URL and access token |
| CloudWatch | Exposes logging credentials |
| Prometheus push gateway | Exposes gateway hostname and port |
| `config` gem (`Settings`) | Rails initializer injects config if `Settings` is defined |

[clowder]: https://github.com/RedHatInsights/clowder
[clowder-schema]: https://raw.githubusercontent.com/RedHatInsights/clowder/master/controllers/cloud.redhat.com/config/schema.json
[schema]: https://raw.githubusercontent.com/RedHatInsights/clowder/master/controllers/cloud.redhat.com/config/schema.json
