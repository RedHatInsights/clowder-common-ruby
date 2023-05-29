require 'ostruct'
require 'json'
require_relative 'types'

module ClowderCommonRuby
  class Config < AppConfig
    # Check if clowder config's ENV var is defined
    # If true, svc is deployed by Clowder
    def self.clowder_enabled?
      !ENV['ACG_CONFIG'].nil? && ENV['ACG_CONFIG'] != ""
    end

    def self.load(acg_config = ENV['ACG_CONFIG'] || 'test.json')
      unless File.exist?(acg_config)
        raise "ERROR: #{acg_config} does not exist"
      end

      new(acg_config)
    end

    def initialize(acg_config)
      super(JSON.parse(File.read(acg_config)))
      kafka_servers
      kafka_topics
      object_buckets
      dependency_endpoints
      private_dependency_endpoints
    end

    # List of Kafka Broker URLs.
    def kafka_servers
      @kafka_servers ||= [].tap do |servers|
        kafka.brokers.each do |broker|
          servers << "{#{broker.hostname}}:{#{broker.port}}"
        end
      end
    end

    # Map of KafkaTopics using the requestedName as the key and the topic object as the value.
    def kafka_topics
      @kafka_topics ||= {}.tap do |topics|
        kafka.topics.each do |topic|
          next if topic.requestedName.nil?

          topics[topic.requestedName] = topic
        end
      end
    end

    # List of ObjectBuckets using the requestedName
    def object_buckets
      @object_buckets ||= {}.tap do |buckets|
        objectStore.buckets.each do |bucket|
          next if bucket.requestedName.nil?

          buckets[bucket.requestedName] = bucket
        end
      end
    end

    # Nested map using [appName][deploymentName]
    # for the public services of requested applications.
    def dependency_endpoints
      @dependency_endpoints ||= {}.tap do |endpts|
        endpoints.each do |endpoint|
          next if endpoint.app.nil? || endpoint.name.nil?

          endpts[endpoint.app]                = {} unless endpts.include?(endpoint.app)
          endpts[endpoint.app][endpoint.name] = endpoint
        end
      end
    end

    # nested map using [appName][deploymentName]
    #   for the private services of requested applications.
    def private_dependency_endpoints
      @private_dependency_endpoints ||= {}.tap do |priv_endpts|
        privateEndpoints.each do |endpoint|
          next if endpoint.app.nil? || endpoint.name.nil?

          priv_endpts[endpoint.app]                = {} unless priv_endpts.include?(endpoint.app)
          priv_endpts[endpoint.app][endpoint.name] = endpoint
        end
      end
    end
  end

  class RailsConfig
    def initialize
      @config = ClowderCommonRuby::Config.load
    end

    # Map for Kafka server configuration
    def configure_kafka_servers
      first_server_config = @config.kafka.brokers[0]
      security_protocol = first_server_config&.dig('authtype')
      final_kafka_config = {
        brokers: @config.kafka_brokers || ''
      }

      if security_protocol
        if security_protocol == 'sasl'
          cacert = first_server_config&.dig('cacert')
          if cacert.present?
            final_kafka_config[:ssl_ca_location] = 'tmp/kafka_ca.crt'
            File.open(final_kafka_config[:ssl_ca_location], 'w') do |f|
              f.write(cacert)
            end unless File.exist?(final_kafka_config[:ssl_ca_location])
          end
          final_kafka_config[:sasl_username] = first_server_config&.dig('sasl', 'username')
          final_kafka_config[:sasl_password] = first_server_config&.dig('sasl', 'password')
          final_kafka_config[:sasl_mechanism] = first_server_config&.dig('sasl', 'saslMechanism')
          final_kafka_config[:security_protocol] = first_server_config&.dig('sasl', 'securityProtocol')
        else
          raise "Unsupported Kafka security protocol '#{security_protocol}'"
        end
      else
        final_kafka_config[:security_protocol] = 'plaintext'
      end
    end
    
    # List of Kafka brokers
    def kafka_brokers
      kafka.brokers&.map do |broker|
        "#{broker.hostname}:#{broker.port}"
      end&.join(',')
    end

    # Nested map for Cloudwatch configuration
    def configure_cloudwatch
      cloudwatch = @config.logging&.cloudwatch
      
      final_cloudwatch_config = {
        region: cloudwatch&.region,
        log_group: cloudwatch&.logGroup,
        log_stream: Socket.gethostname,
        type: @config.logging&.type,
        credentials: {
          access_key_id: cloudwatch&.accessKeyId,
          secret_access_key: cloudwatch&.secretAccessKey
        }
      }
    end  

    # Map for RBAC configuration 
    def configure_rbac
      rbac_config = @config.dependency_endpoints.dig('rbac', 'service')

      if @config.tlsCAPath
        rbac_host = "#{rbac_config.hostname}:#{rbac_config.tlsPort}"
        rbac_scheme = 'https'
      else
        rbac_host = "#{rbac_config.hostname}:#{rbac_config.port}"
        rbac_scheme = 'http'
      end

      final_rbac_config = {
        host: rbac_host,
        scheme: rbac_scheme
      }
    end

    # String http url 
    def build_http_url(endpoint)
      URI::HTTP.build(host: endpoint&.hostname, port: endpoint&.port).to_s
    end

    # String https url 
    def build_https_url(endpoint)
      URI::HTTPS.build(host: endpoint&.hostname, port: endpoint&.tlsPort).to_s
    end

    # Nested map for Rails configuration
    def self.to_hash
      rails_config = new
    
      # Kafka
      kafka_server_config = rails_config.configure_kafka_servers

      # Cloudwatch
      cloudwatch_config = rails_config.configure_cloudwatch

      # RBAC
      rbac_config = rails_config.configure_rbac

      # Redis (in-memory db)
      redis_url = "#{@config.dig('inMemoryDb', 'hostname')}:#{@config.dig('inMemoryDb', 'port')}"
      redis_password = @config.dig('inMemoryDb', 'password')
    
      clowder_config = {
        kafka: kafka_server_config,
        logging: cloudwatch_config,
        rbac: rbac_config,
        redis_url: redis_url,
        redis_password: redis_password,
        clowder_config_enabled: true,
        prometheus_exporter_port: @config&.metricsPort
      }

      unless @config.private_dependency_endpoints.nil?
        if @config.tlsCAPath
          @config.private_dependency_endpoints.each do |endpoint|
            key = ":#{endpoint.app}_url"
            clowder_config[key] = build_https_url(endpoint)
          end
        else
          @config.private_dependency_endpoints.each do |endpoint|
            key = ":#{endpoint.app}_url"
            clowder_config[key] = build_http_url(endpoint)
          end
        end
      end

      unless @config.dependency_endpoints.nil?
        if @config.tlsCAPath
          @config.dependency_endpoints.each do |endpoint|
            key = ":#{endpoint.app}_url"
            clowder_config[key] = build_https_url(endpoint) unless endpoint.app = "rbac"
          end
        else
          @config.dependency_endpoints.each do |endpoint|
            key = ":#{endpoint.app}_url"
            clowder_config[key] = build_http_url(endpoint) unless endpoint.app = "rbac"
          end
        end
      end
    end
  end
end
