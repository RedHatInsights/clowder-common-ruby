app-common-ruby
=================

Simple client access library for the config for the Clowder operator.

Based on schema.json, the corresponding Ruby Classes are generated in types.rb.

Usage
-----

To access configuration, see the following example

```
require 'app-common-ruby'

def test()
  if IsClowderEnabled()
    puts "Public port: #{LoadedConfig.publicPort}"
  end
end
```

The ``clowder`` library also comes with several other helpers

* ``KafkaTopics`` - returns a map of KafkaTopics using the requestedName
  as the key and the topic object as the value.
* ``KafkaServers`` - returns a list of Kafka Broker URLs.
* ``ObjectBuckets`` - returns a list of ObjectBuckets using the requestedName
  as the key and the bucket object as the value.
* ``DependencyEndpoints`` - returns a nested map using \[appName\]\[deploymentName\] 
  for the public services of requested applications. 
* ``PrivateDependencyEndpoints`` - returns a nested map using \[appName\]\[deploymentName\] 
  for the private services of requested applications.

Testing
-------

export `ACG_CONFIG="test.json"; ruby config.rb
