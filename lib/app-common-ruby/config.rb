require 'ostruct'
require 'json'
require_relative 'types'

arg_config = ENV.fetch('ACG_CONFIG')

unless File.exist?(arg_config)
  puts "ERROR: #{arg_config} does not exist"
  exit 1
end

def IsClowderEnabled()
  return ENV["ACG_CONFIG"] != "" ? true : false
end

LoadedConfig = AppConfig.new(JSON.parse(File.read(arg_config)))

KafkaTopics = {}.tap do |topics|
  LoadedConfig.kafka.topics.each do |topic|
    topics[topic.requestedName] = topic
  end
end

ObjectBuckets = {}.tap do |buckets|
  LoadedConfig.objectStore.buckets.each do |bucket|
    buckets[bucket.requestedName] = bucket
  end
end

DependencyEndpoints = {}.tap do |endpoints|
  LoadedConfig.endpoints.each do |endpoint|
    endpoints[endpoint.app] = {} unless endpoints.include?(endpoint.app)
    endpoints[endpoint.app][endpoint.name] = endpoint
  end
end

PrivateDependencyEndpoints = {}.tap do |privateEndpoints|
  LoadedConfig.privateEndpoints.each do |endpoint|
    privateEndpoints[endpoint.app] = {} unless privateEndpoints.include?(endpoint.app)
    privateEndpoints[endpoint.app][endpoint.name] = endpoint
  end
end

KafkaServers = [].tap do |servers|
  LoadedConfig.kafka.brokers.each do |broker|
    servers << "{#{broker.hostname}}:{#{broker.port}}"
  end
end
