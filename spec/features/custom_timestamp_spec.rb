describe "VIN custom timestamp feature" do
  include DummyData

  subject { VIN.new(config: config) }

  let(:config) { VIN::Config.new }
  let(:data_type) { random_data_type }
  let(:now_ms) { (Time.now.to_f * 1000).to_i }
  let(:custom_timestamp) { config.custom_epoch + 86_400_000 } # 1 day after custom epoch
  let(:generator) { subject.send(:generator) }

  before do
    VIN::LuaScript.reset_cache

    # Track state for mock responses
    sequence_counter = 0
    shard_counter = 0

    # Mock the generator's response method to return dummy responses
    allow(generator).to receive(:response) do
      # Get count from the generator (for batch generation)
      count = generator.instance_variable_get(:@count) || 1

      # Use custom timestamp if provided, otherwise use current time
      if generator.instance_variable_get(:@custom_timestamp)
        timestamp_ms = generator.instance_variable_get(:@custom_timestamp)
        time = Time.at(timestamp_ms / 1000.0)
      else
        time = Time.now
      end

      # Use the dummy_redis_response helper to generate consistent responses
      redis_response = dummy_redis_response(
        count: count,
        sequence_start: sequence_counter + 1,
        logical_shard_id: shard_counter % 8,
        now: time,
      )

      # Update counters for next call
      sequence_counter = redis_response[1] # end_sequence
      shard_counter += 1

      VIN::Response.new(redis_response)
    end
  end

  describe "#generate_id with custom timestamp" do
    context "when timestamp is valid" do
      it "generates an ID with the provided timestamp" do
        id = subject.generate_id(data_type, timestamp: custom_timestamp)
        expect(id).to be_a(Integer)

        # Extract timestamp from the ID
        vin_id = VIN::Id.new(id: id, config: config)
        expected_timestamp_ms = custom_timestamp - config.custom_epoch

        # The timestamp in the ID should match the custom timestamp (relative to custom epoch)
        expect(vin_id.timestamp.milliseconds).to eq(expected_timestamp_ms)
      end

      it "generates different IDs when called multiple times with the same timestamp" do
        id1 = subject.generate_id(data_type, timestamp: custom_timestamp)
        id2 = subject.generate_id(data_type, timestamp: custom_timestamp)

        expect(id1).not_to eq(id2)

        # Both should have the same timestamp
        vin_id1 = VIN::Id.new(id: id1, config: config)
        vin_id2 = VIN::Id.new(id: id2, config: config)

        expect(vin_id1.timestamp.milliseconds).to eq(vin_id2.timestamp.milliseconds)

        # IDs should be different due to either different sequences or different logical shard IDs
        # (The Lua script round-robins through logical shard IDs, each with its own sequence counter)
        if vin_id1.logical_shard_id == vin_id2.logical_shard_id
          expect(vin_id1.sequence).not_to eq(vin_id2.sequence)
        else
          # Different logical shards can have the same sequence, but that's fine
          expect(vin_id1.logical_shard_id).not_to eq(vin_id2.logical_shard_id)
        end
      end
    end

    context "when timestamp is before custom epoch" do
      let(:custom_timestamp) { config.custom_epoch - 1000 } # 1 second before custom epoch

      it "raises an ArgumentError" do
        expect do
          subject.generate_id(data_type, timestamp: custom_timestamp)
        end.to raise_error(ArgumentError, /timestamp cannot be before the custom epoch/)
      end
    end

    context "when timestamp is not an integer" do
      let(:custom_timestamp) { "not_a_timestamp" }

      it "raises an ArgumentError" do
        expect do
          subject.generate_id(data_type, timestamp: custom_timestamp)
        end.to raise_error(ArgumentError, /timestamp must be an integer/)
      end
    end

    context "when timestamp is nil" do
      it "generates an ID using Redis timestamp" do
        id = subject.generate_id(data_type, timestamp: nil)
        expect(id).to be_a(Integer)

        # The ID should have a recent timestamp (within the last few seconds)
        vin_id = VIN::Id.new(id: id, config: config)
        unix_timestamp = vin_id.timestamp.with_unix_epoch.milliseconds

        expect(unix_timestamp).to be_within(5000).of(now_ms)
      end
    end
  end

  describe "#generate_ids with custom timestamp" do
    let(:count) { 5 }

    context "when timestamp is valid" do
      it "generates multiple IDs with the provided timestamp" do
        ids = subject.generate_ids(data_type, count, timestamp: custom_timestamp)

        expect(ids.length).to eq(count)
        expect(ids.uniq.length).to eq(count) # All IDs should be unique

        # All IDs should have the same timestamp
        timestamps = ids.map do |id|
          VIN::Id.new(id: id, config: config).timestamp.milliseconds
        end

        expect(timestamps.uniq.length).to eq(1)
        expect(timestamps.first).to eq(custom_timestamp - config.custom_epoch)
      end

      it "generates sequential IDs with increasing sequences" do
        ids = subject.generate_ids(data_type, count, timestamp: custom_timestamp)

        sequences = ids.map do |id|
          VIN::Id.new(id: id, config: config).sequence
        end

        # Sequences should be consecutive
        sequences.each_cons(2) do |a, b|
          expect(b - a).to eq(1)
        end
      end
    end

    context "when requesting many IDs with the same timestamp" do
      let(:count) { 100 }

      it "generates all unique IDs" do
        ids = subject.generate_ids(data_type, count, timestamp: custom_timestamp)

        expect(ids.length).to eq(count)
        expect(ids.uniq.length).to eq(count)

        # All should have the same timestamp
        timestamps = ids.map do |id|
          VIN::Id.new(id: id, config: config).timestamp.milliseconds
        end

        expect(timestamps.uniq.length).to eq(1)
      end
    end
  end

  # NOTE: Concurrent ID generation with same timestamp is not tested here because:
  # 1. The mock responses are synchronized, which doesn't truly test concurrency
  # 2. RSpec mocks aren't thread-safe without additional synchronization
  # 3. The real concurrency guarantees come from Redis's atomic operations (INCRBY)
  #    and the Lua script's distributed locking mechanism
  # 4. True concurrent testing would require integration tests with a real Redis instance
  #
  # The uniqueness of IDs with the same timestamp is still tested through:
  # - Sequential calls with the same timestamp (see tests above)
  # - The round-robin logical shard ID assignment
  # - The sequence incrementing within each shard

  describe "timestamp conversion and epoch handling" do
    let(:unix_timestamp_ms) { config.custom_epoch + 3_600_000 } # 1 hour after custom epoch
    let(:custom_timestamp) { unix_timestamp_ms }

    it "correctly converts Unix timestamp to custom epoch relative timestamp" do
      id = subject.generate_id(data_type, timestamp: custom_timestamp)
      vin_id = VIN::Id.new(id: id, config: config)

      # The timestamp should be relative to custom epoch
      expected_ms_from_epoch = custom_timestamp - config.custom_epoch
      expect(vin_id.timestamp.milliseconds).to eq(expected_ms_from_epoch)

      # When converted back to Unix time, it should match the original
      unix_ms = vin_id.timestamp.with_unix_epoch.milliseconds
      expect(unix_ms).to eq(custom_timestamp)
    end

    it "produces the same Time object as IDs generated without custom timestamp" do
      # Generate ID with custom timestamp
      custom_id = subject.generate_id(data_type, timestamp: custom_timestamp)
      custom_vin_id = VIN::Id.new(id: custom_id, config: config)

      # The to_time method should produce the correct Time object
      time_from_custom = custom_vin_id.timestamp.to_time
      expected_time = Time.at(custom_timestamp / 1000.0)

      expect(time_from_custom.to_i).to eq(expected_time.to_i)
    end
  end
end
