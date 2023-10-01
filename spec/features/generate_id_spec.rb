# frozen_string_literal: true

describe "VIN.generate_id" do
  include DummyData

  subject { instance.generate_id(data_type) }

  let(:config) { VIN::Config.new(logical_shard_id_range: logical_shard_id_range) }
  let(:data_type) { random_data_type }
  let(:id) { VIN::Id.new(id: subject, config: config) }
  let(:instance) { VIN.new(config: config) }
  let(:logical_shard_id_range) { random_logical_shard_id_range }
  let(:generator) { instance.send(:generator) }
  let(:now) { Time.now }
  let(:first_stub_response) do
    VIN::Response.new(
      dummy_redis_response(
        sequence_start: 123,
        logical_shard_id: logical_shard_id_range.min,
        now: now,
      ),
    )
  end
  let(:second_stub_response) do
    VIN::Response.new(
      dummy_redis_response(
        sequence_start: 124,
        logical_shard_id: logical_shard_id_range.min,
        now: now,
      ),
    )
  end

  before do
    allow(generator).to(receive(:response).and_return(first_stub_response, second_stub_response))
    VIN::LuaScript.reset_cache
  end

  it "returns a new ID" do
    expect(subject).to(be_a(Numeric))
  end

  context "when generating IDs from one server" do
    let(:logical_shard_id_range) { 0..0 }

    it "increases with each call" do
      expect(subject).to(be < instance.generate_id(data_type))
    end

    context "when two IDs are generated within the same millisecond" do
      it "increases the sequence number" do
        first_id = VIN::Id.new(id: instance.generate_id(data_type), config: config)
        second_id = VIN::Id.new(id: instance.generate_id(data_type), config: config)
        expect(first_id.timestamp.milliseconds).to(eql(second_id.timestamp.milliseconds))
        expect(first_id.sequence).to(be < second_id.sequence)
      end
    end
  end

  it "contains a current timestamp" do
    expect(id.timestamp).to(be_a(VIN::Timestamp))
    expect(id.custom_timestamp).to(be_between(0, ~(-1 << config.timestamp_bits)))
    expect(id.timestamp.to_time).to(be_between((Time.now - 1), (Time.now + 1)))
  end

  context "when logical_shard_id_range is a range" do
    it "contains one of the logical shard IDs" do
      expect(id.logical_shard_id).to(be_a(Numeric))
      expect(id.logical_shard_id).to(be_between(config.min_logical_shard_id, config.max_logical_shard_id))
      expect(id.logical_shard_id).to(be_between(logical_shard_id_range.min, logical_shard_id_range.max))
    end
  end

  context "when logical_shard_id_range is one number" do
    let(:shard_id) { random_logical_shard_id }
    let(:logical_shard_id_range) { shard_id..shard_id }

    it "contains the logical shard ID" do
      expect(id.logical_shard_id).to(be_a(Numeric))
      expect(id.logical_shard_id).to(be_between(config.min_logical_shard_id, config.max_logical_shard_id))
      expect(id.logical_shard_id).to(eql(shard_id))
    end
  end

  it "contains the data type" do
    expect(id.data_type).to(be_a(Numeric))
    expect(id.data_type).to(be_between(0, ~(-1 << config.data_type_bits)))
    expect(id.data_type).to(eql(data_type))
  end

  it "contains a sequence" do
    expect(id.sequence).to(be_a(Numeric))
    expect(id.sequence).to(be_between(0, config.max_sequence))
  end

  context "when the Redis server has more than one logical shard ID" do
    subject do
      10.times.map do |i|
        expected_response = VIN::Response.new(dummy_redis_response(logical_shard_id: (i % 2) + 1))
        allow(generator).to(receive(:response).and_return(expected_response))
        VIN::Id.new(id: instance.generate_id(data_type), config: config)
      end
    end

    let(:logical_shard_id_range) { 1..2 }

    it "uses all logical shard IDs" do
      ones = subject.select { |id| id.logical_shard_id == 1 }
      twos = subject.select { |id| id.logical_shard_id == 2 }

      expect(ones.length).to(eql(twos.length))
    end

    it "increments the per-shard sequence" do
      logical_shard_id_range.to_a.each do |shard_id|
        shard_sequences = subject.select { |id| id.logical_shard_id == shard_id }.map(&:sequence)
        expect(shard_sequences).to(eql(shard_sequences.sort))
      end
    end
  end
end
