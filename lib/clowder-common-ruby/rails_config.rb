require 'clowder-common-ruby'

module ClowderCommonRuby
  class RailsConfig
    class << self
      # Rails configuration hash
      def to_h
        config = ClowderCommonRuby::Config.load

        {
          kafka: configure_kafka(config),
          logging: configure_cloudwatch(config),
          redis: configure_redis(config),
          endpoints: configure_endpoints(config, :dependency_endpoints),
          private_endpoints: configure_endpoints(config, :private_dependency_endpoints),
          database: configure_database(config),
          prometheus_exporter_port: config&.metricsPort,
          tls_ca_path: config.tlsCAPath,
          web_port: config.webPort
        }
      end

      # Short path for db config
      def db_config
        config = ClowderCommonRuby::Config.load

        configure_database(config)
      end

      private

      # Kafka configuration hash
      def configure_kafka(config)
        # In case there are no kafka brokers, an empty string is ensured in place of ':'
        build_kafka_security(config).merge(
          brokers: build_kafka_brokers(config) || '',
          topics: build_kafka_topics(config)
        )
      end

      # Kafka security settings hash
      def build_kafka_security(config)
        server_config = config.kafka.brokers[0]
        authtype = server_config&.dig('authtype')
        cacert = server_config&.dig('cacert')

        return { security_protocol: 'plaintext' } unless authtype

        unless authtype == 'sasl'
          raise "Unsupported Kafka security protocol '#{authtype}'"
        end

        {
          sasl_username: server_config&.dig('sasl', 'username'),
          sasl_password: server_config&.dig('sasl', 'password'),
          sasl_mechanism: server_config&.dig('sasl', 'saslMechanism'),
          security_protocol: server_config&.dig('sasl', 'securityProtocol'),
          ssl_ca_location: build_kafka_certificate(cacert)
        }.compact
        # In case build_kafka_certificate returns nil, ssl_ca_location is removed from the hash with compact
      end

      # Gives location of ssl certificate and makes sure it exists
      def build_kafka_certificate(cacert)
        return unless cacert.present?

        ssl_ca_location = Rails.root.join('tmp', 'kafka_ca.crt')

        write_temporary_file(ssl_ca_location, cacert)

        ssl_ca_location
      end

      # Kafka brokers list
      def build_kafka_brokers(config)
        config.kafka.brokers&.map do |broker|
          "#{broker.hostname}:#{broker.port}"
        end&.join(',')
      end

      # Kafka topics hash
      def build_kafka_topics(config)
        config.kafka.topics&.each_with_object({}) do |topic, obj|
          k = "#{topic.name.sub(/^platform./, '')}".parameterize.underscore.to_sym
          obj[k] = topic.name
        end
      end

      # Redis configuration hash
      def configure_redis(config)
        inMemoryDb = config&.dig('inMemoryDb')
        redis_url = "redis://#{inMemoryDb.dig('hostname')}:#{inMemoryDb.dig('port')}"

        {
          url: redis_url,
          password: inMemoryDb.dig('password'),
          ssl: inMemoryDb.dig('sslMode')
        }
      end

      # Cloudwatch configuration hash
      def configure_cloudwatch(config)
        cloudwatch = config.logging&.cloudwatch

        {
          region: cloudwatch&.region,
          log_group: cloudwatch&.logGroup,
          log_stream: Socket.gethostname,
          type: config.logging&.type,
          credentials: {
            access_key_id: cloudwatch&.accessKeyId,
            secret_access_key: cloudwatch&.secretAccessKey
          }
        }
      end

      # All endpoints' configuration hash
      def configure_endpoints(config, field)
        config.try(field)&.each_with_object({}) do |(name, endpoint), obj|
          service = endpoint.dig('service')

          next unless service

          key = name.underscore.to_sym
          obj[key] = build_endpoint(config, service)
        end
      end

      # Endpoint configuration hash
      def build_endpoint(config, endpoint)
        scheme = config.tlsCAPath ? 'https' : 'http'
        port = config.tlsCAPath ? endpoint.tlsPort : endpoint.port
        host = "#{endpoint.hostname}:#{port}"

        {
          scheme: scheme,
          host: host,
          url: "#{scheme}://#{host}"
        }
      end

      # Database configuration hash
      def configure_database(config)
        {
          database: config.database.name,
          username: config.database.username,
          password: config.database.password,
          host: config.database.hostname,
          port: config.database.port,
          admin_username: config.database.adminUsername,
          admin_password: config.database.adminPassword,
          rds_ca: config.database.rdsCa,
          ssl_mode: config.database.sslMode,
          ssl_root_cert: build_database_certificate(config.database.rdsCa)
        }
      end

      # Gives location of database ssl certificate and makes sure it exists
      def build_database_certificate(rdsca)
        return unless rdsca.present?

        db_config = Rails.root.join('tmp', 'rdsCa')

        write_temporary_file(db_config, rdsca)

        db_config
      end

      # Creates and writes file if it doesn't exist
      def write_temporary_file(path, content)
        File.open(path, 'w') do |f|
          f.write(content)
        end unless File.exist?(path)
      end
    end
  end
end
