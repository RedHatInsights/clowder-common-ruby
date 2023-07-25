clowder-common-ruby
=================

Simple client access library for the config for the Clowder operator.

Based on schema.json, the corresponding Ruby Classes are generated in types.rb.

Usage
-----

The `clowder` library provides basic values like expected public port, metrics port,
database credentials etc.

Usage:

```
require 'clowder-common-ruby'

@config ||= {}.tap do |options|
    # uses ENV['ACG_CONFIG'] or you can provide the path as a method param

  if ClowderCommonRuby::Config.clowder_enabled?
    config = ClowderCommonRuby::Config.load
    options["publicPort"]         = config.publicPort
    options["databaseHostname"] = config.database.hostname
    options["kafkaTopics"]      = config.kafka_topics
    # ...
  else
    options["publicPort"] = 3000
    options["databaseHostname"] = ENV['DATABASE_HOST']
  end
end
```

The ``clowder`` library also comes with several other helpers

* ``config.kafka_topics`` - returns a map of KafkaTopics using the requestedName
  as the key and the topic object as the value.
* ``config.kafka_servers`` - returns a list of Kafka Broker URLs.
* ``config.object_buckets`` - returns a list of ObjectBuckets using the requestedName
  as the key and the bucket object as the value.
* ``config.dependency_endpoints`` - returns a nested map using \[appName\]\[deploymentName\]
  for the public services of requested applications.
* ``config.private_dependency_endpoints`` - returns a nested map using \[appName\]\[deploymentName\]
  for the private services of requested applications.


See [test.json](test.json) for all available values

### Usage in Rails 

In Rails applications, requiring the ```clowder-common-ruby/engine``` will run the initializer, the output of which will be accessible under ```Settings```.  

### Kafka Topics

Topics are structured as a hash `<requested_name> => <name>`
where `requested_name` is equal to the key topicName in your ClowdApp Custom Resource Definition(CRD)'s yaml

If your kafka is deployed in `local` or `app-interface` mode (see [doc](https://clowder-operator.readthedocs.io/en/latest/providers/kafka.html))
the `name` is equal to the `requested_name`.

Testing
-------

`ACG_CONFIG="test.json" ruby lib/clowder-common-ruby/test.rb`

It inspects and prints the config file with loaded values or shows an error it the env. variable not configured correctly
