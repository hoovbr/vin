describe "VIN.generate_ids" do
  include DummyData

  subject { instance.generate_ids(data_type, count) }

  let(:instance) { VIN.new(config: config) }
  let(:data_type) { random_data_type }
  let(:count) { 3 }
  let(:config) { VIN::Config.new }
  let(:ids) { subject.map { |id| VIN::Id.new(id:, config:) } }
  let(:generator) { instance.send(:generator) }
  let(:logical_shard_id_range) { random_logical_shard_id_range }
  let(:logical_shard_id) { logical_shard_id_range.min }
  let(:stub_response) do
    VIN::Response.new(dummy_redis_response(logical_shard_id: logical_shard_id))
  end

  before do
    allow(generator).to(receive(:response).and_return(stub_response))
    VIN::LuaScript.reset_cache
  end

  it "returns new IDs" do
    expect(subject).to(all(be_a(Numeric)))
    expect(subject.length).to(eql(count))
  end

  it "increases with each call" do
    expect(subject).to(eql(subject.sort))
  end

  it "contains a current timestamp" do
    expect(ids.map(&:timestamp)).to(all(be_a(VIN::Timestamp)))
    expect(ids.map(&:custom_timestamp)).to(all(be_between(0, ~(-1 << config.timestamp_bits))))
    expect(ids.map(&:timestamp).map(&:to_time)).to(all(be_between(Time.now - 1, Time.now + 1)))
  end

  context "when logical_shard_id_range is a range" do
    let(:logical_shard_id_range) { random_logical_shard_id_range }
    let(:config) { VIN::Config.new(logical_shard_id_range: logical_shard_id_range) }

    it "contains one of the logical shard IDs" do
      expect(ids.map(&:logical_shard_id)).to(all(be_a(Numeric)))
      expect(ids.map(&:logical_shard_id)).to(all(be_between(config.min_logical_shard_id, config.max_logical_shard_id)))
      expect(ids.map(&:logical_shard_id)).to(all(be_between(logical_shard_id_range.min, logical_shard_id_range.max)))
    end
  end

  context "when logical_shard_id_range is one number" do
    let(:logical_shard_id) { random_logical_shard_id }
    let(:config) { VIN::Config.new(logical_shard_id_range: logical_shard_id..logical_shard_id) }

    it "contains the logical shard ID" do
      expect(ids.map(&:logical_shard_id)).to(all(be_a(Numeric)))
      expect(ids.map(&:logical_shard_id)).to(all(be_between(config.min_logical_shard_id, config.max_logical_shard_id)))
      expect(ids.map(&:logical_shard_id)).to(all(eql(logical_shard_id)))
    end
  end

  it "contains a sequence" do
    expect(ids.map(&:sequence)).to(all(be_a(Numeric)))
    expect(ids.map(&:sequence)).to(all(be_between(0, config.max_sequence)))
    expect(ids.map(&:sequence)).to(eql(ids.map(&:sequence).sort))
  end

  context "when count is more than the Lua script can return in one shot" do
    let(:count) { config.max_sequence + 100 }

    it "generates the requested amount of IDs" do
      expect(subject.length).to(eql(count))
    end
  end
end
