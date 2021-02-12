require 'app-common-ruby'
require 'climate_control'

describe AppCommonRuby do
  around do |example|
    ClimateControl.modify(:ACG_CONFIG => "./test.json") { example.call }
  end

  it "should have KafkaTopics" do
    topic_config = KafkaTopics["originalName"]

    expect(topic_config.class).to eq(TopicConfig)
    expect(topic_config.requestedName).to eq("originalName")
    expect(topic_config.name).to eq("someTopic")
    expect(topic_config.consumerGroup).to eq("someGroupName")
  end

  it "should have ObjectBuckets" do
    bucket = ObjectBuckets["reqname"]

    expect(bucket.class).to eq(ObjectStoreBucket)
    expect(bucket.requestedName).to eq("reqname")
    expect(bucket.accessKey).to eq("accessKey1")
    expect(bucket.secretKey).to eq("secretKey1")
    expect(bucket.name).to eq("name")
  end

  it "should have DependencyEndpoints" do
    expect(DependencyEndpoints.count).to eq(2)
    expect(DependencyEndpoints["app1"]["endpoint1"].class).to eq(DependencyEndpoint)
    expect(DependencyEndpoints["app2"]["endpoint2"].class).to eq(DependencyEndpoint)

    expect(DependencyEndpoints["app1"]["endpoint1"].hostname).to eq("endpoint1.svc")
    expect(DependencyEndpoints["app1"]["endpoint1"].port).to eq(8000)
    expect(DependencyEndpoints["app2"]["endpoint2"].hostname).to eq("endpoint2.svc")
    expect(DependencyEndpoints["app2"]["endpoint2"].port).to eq(8000)
  end


  it "should have PrivateDependencyEndpoints" do
    expect(PrivateDependencyEndpoints.count).to eq(2)
    expect(PrivateDependencyEndpoints["app1"]["endpoint1"].class).to eq(PrivateDependencyEndpoint)
    expect(PrivateDependencyEndpoints["app2"]["endpoint2"].class).to eq(PrivateDependencyEndpoint)

    expect(PrivateDependencyEndpoints["app1"]["endpoint1"].hostname).to eq("endpoint1.svc")
    expect(PrivateDependencyEndpoints["app1"]["endpoint1"].port).to eq(10000)
    expect(PrivateDependencyEndpoints["app2"]["endpoint2"].hostname).to eq("endpoint2.svc")
    expect(PrivateDependencyEndpoints["app2"]["endpoint2"].port).to eq(10000)
  end

  it "should have KafkaServers" do
    expect(KafkaServers.count).to eq(1)
    expect(KafkaServers.first).to eq("{broker-host}:{27015}")
  end

  it "should return enabled is true in a test" do
    expect(IsClowderEnabled()).to eq(true)
  end
end
