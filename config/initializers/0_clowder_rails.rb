require 'clowder-common-ruby/rails_config'

if ClowderCommonRuby::Config.clowder_enabled?
  config = ClowderCommonRuby::RailsConfig.to_h

  if config.dig('tls_ca_path')
    ENV['SSL_CERT_FILE'] = Rails.root.join('tmp', 'cacert.crt')

    File.open(ENV['SSL_CERT_FILE'], 'w') do |f|
      f.write(File.read('/etc/pki/tls/certs/ca-bundle.crt'))
      f.write(File.read('/cdapp/certs/service-ca.crt'))
    end
  end

  Settings.add_source!(config)
  Settings.reload!
end
