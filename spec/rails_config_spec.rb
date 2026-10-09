require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/string/inflections'
require 'clowder-common-ruby/rails_config'

describe ClowderCommonRuby::RailsConfig do
  let(:legacy_endpoint) do
    ClowderCommonRuby::DependencyEndpoint.new(
      'hostname' => 'rbac-v1.example.com',
      'port' => 8080,
      'tlsPort' => 8443
    )
  end

  let(:v1_config) do
    {
      'rbac' => {
        'service' => legacy_endpoint
      }
    }
  end

  let(:v2_config) { {} }

  let(:config) do
    OpenStruct.new(
      tlsCAPath: nil,
      dependency_endpoints: v1_config,
      v2_dependency_endpoints: v2_config,
      private_dependency_endpoints: v1_config,
      v2_private_dependency_endpoints: v2_config
    )
  end

  describe '.configure_endpoints' do
    it 'projects V1 service endpoints to the existing endpoint settings' do
      endpoints = described_class.send(:configure_endpoints, config, :dependency_endpoints)

      expect(endpoints[:rbac]).to eq(
        scheme: 'http',
        host: 'rbac-v1.example.com:8080',
        url: 'http://rbac-v1.example.com:8080',
        ca_certificate: nil,
        authenticated: false,
        source: :v1
      )
    end
  end

  describe '.configure_v2_endpoints' do
    it 'projects V2 service values and metadata separately from V1' do
      v2_endpoint = ClowderCommonRuby::DependencyEndpointV2.new(
        'uri' => 'https://rbac.example.com:9443/base',
        'ca_certificate' => '/certs/rbac-ca.crt',
        'authenticated' => true
      )
      other_endpoint = ClowderCommonRuby::DependencyEndpointV2.new(
        'uri' => 'http://other-rbac.example.com:8080',
        'authenticated' => false
      )
      allow(config).to receive(:v2_dependency_endpoints).and_return(
        'rbac' => {
          'service' => v2_endpoint,
          'endpoint1' => other_endpoint
        }
      )

      endpoints = described_class.send(:configure_v2_endpoints, config, :v2_dependency_endpoints)

      expect(endpoints[:rbac][:service]).to eq(
        scheme: 'https',
        host: 'rbac.example.com:9443',
        url: 'https://rbac.example.com:9443/base',
        ca_certificate: '/certs/rbac-ca.crt',
        authenticated: true,
        source: :v2
      )
      expect(endpoints[:rbac][:endpoint1]).to include(
        url: 'http://other-rbac.example.com:8080',
        authenticated: false,
        source: :v2
      )
    end

    it 'returns an empty map when V2 is missing or invalid' do
      invalid_v2_endpoint = ClowderCommonRuby::DependencyEndpointV2.new(
        'uri' => 'not a valid URI',
        'authenticated' => true
      )
      allow(config).to receive(:v2_dependency_endpoints).and_return(
        'rbac' => { 'service' => invalid_v2_endpoint }
      )

      endpoints = described_class.send(:configure_v2_endpoints, config, :v2_dependency_endpoints)

      expect(endpoints).to eq({})
    end

    it 'projects private V2 endpoints' do
      private_endpoint = ClowderCommonRuby::DependencyEndpointV2.new(
        'uri' => 'https://private-rbac.example.com:9443',
        'ca_certificate' => '/certs/private-ca.crt',
        'authenticated' => true
      )
      allow(config).to receive(:v2_private_dependency_endpoints).and_return(
        'rbac' => { 'service' => private_endpoint }
      )

      endpoints = described_class.send(
        :configure_v2_endpoints,
        config,
        :v2_private_dependency_endpoints
      )

      expect(endpoints[:rbac][:service]).to include(
        url: 'https://private-rbac.example.com:9443',
        ca_certificate: '/certs/private-ca.crt',
        authenticated: true,
        source: :v2
      )
    end
  end

  describe '.to_h' do
    it 'includes both V1 and V2 endpoints in separate public and private Settings sources' do
      public_endpoint = ClowderCommonRuby::DependencyEndpointV2.new(
        'uri' => 'https://rbac.example.com:9443',
        'ca_certificate' => '/certs/rbac-ca.crt',
        'authenticated' => true
      )
      private_endpoint = ClowderCommonRuby::DependencyEndpointV2.new(
        'uri' => 'https://private-rbac.example.com:9443',
        'authenticated' => true
      )
      allow(config).to receive(:v2_dependency_endpoints).and_return(
        'rbac' => { 'service' => public_endpoint }
      )
      allow(config).to receive(:v2_private_dependency_endpoints).and_return(
        'rbac' => { 'service' => private_endpoint }
      )
      allow(ClowderCommonRuby::Config).to receive(:load).and_return(config)
      allow(described_class).to receive(:configure_kafka).and_return({})
      allow(described_class).to receive(:configure_cloudwatch).and_return({})
      allow(described_class).to receive(:configure_redis).and_return({})
      allow(described_class).to receive(:configure_database).and_return({})
      allow(described_class).to receive(:configure_unleash).and_return({})

      settings = described_class.to_h

      expect(settings[:endpoints][:rbac]).to include(
        url: 'http://rbac-v1.example.com:8080',
        ca_certificate: nil,
        authenticated: false,
        source: :v1
      )
      expect(settings[:v2_endpoints][:rbac][:service]).to include(
        url: 'https://rbac.example.com:9443',
        ca_certificate: '/certs/rbac-ca.crt',
        authenticated: true,
        source: :v2
      )
      expect(settings[:private_endpoints][:rbac]).to include(
        url: 'http://rbac-v1.example.com:8080',
        ca_certificate: nil,
        authenticated: false,
        source: :v1
      )
      expect(settings[:v2_private_endpoints][:rbac][:service]).to include(
        url: 'https://private-rbac.example.com:9443',
        authenticated: true,
        source: :v2
      )
    end
  end
end
