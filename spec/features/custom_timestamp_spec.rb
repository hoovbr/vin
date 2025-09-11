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

  describe "#generate_ids_from_timestamps with custom timestamp" do
    context "when timestamp is valid" do
      it "generates an ID with the provided timestamp" do
        ids = subject.generate_ids_from_timestamps(data_type, timestamps: [custom_timestamp])
        expect(ids.length).to eq(1)
        id = ids.first
        expect(id).to be_a(Integer)

        # Extract timestamp from the ID
        vin_id = VIN::Id.new(id: id, config: config)
        expected_timestamp_ms = custom_timestamp - config.custom_epoch

        # The timestamp in the ID should match the custom timestamp (relative to custom epoch)
        expect(vin_id.timestamp.milliseconds).to eq(expected_timestamp_ms)
      end

      it "generates different IDs when called multiple times with the same timestamp" do
        ids1 = subject.generate_ids_from_timestamps(data_type, timestamps: [custom_timestamp])
        ids2 = subject.generate_ids_from_timestamps(data_type, timestamps: [custom_timestamp])

        id1 = ids1.first
        id2 = ids2.first

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
          subject.generate_ids_from_timestamps(data_type, timestamps: [custom_timestamp])
        end.to raise_error(ArgumentError, /timestamp cannot be before the custom epoch/)
      end
    end

    context "when timestamp is not an integer" do
      let(:custom_timestamp) { "not_a_timestamp" }

      it "raises an ArgumentError" do
        expect do
          subject.generate_ids_from_timestamps(data_type, timestamps: [custom_timestamp])
        end.to raise_error(ArgumentError, /timestamp must be an integer/)
      end
    end

    context "when timestamp is nil" do
      it "raises an ArgumentError" do
        expect do
          subject.generate_ids_from_timestamps(data_type, timestamps: [nil])
        end.to raise_error(ArgumentError, /timestamp must be an integer/)
      end
    end
  end

  describe "#generate_ids_from_timestamps with multiple timestamps" do
    context "when timestamps are valid" do
      let(:custom_timestamp2) { config.custom_epoch + 172_800_000 } # 2 days after custom epoch

      it "generates multiple IDs with the provided timestamps" do
        timestamps = [custom_timestamp, custom_timestamp2]
        ids = subject.generate_ids_from_timestamps(data_type, timestamps: timestamps)

        expect(ids.length).to eq(2)

        # Each ID should have its corresponding timestamp
        vin_id1 = VIN::Id.new(id: ids[0], config: config)
        vin_id2 = VIN::Id.new(id: ids[1], config: config)

        expected_timestamp_ms1 = custom_timestamp - config.custom_epoch
        expected_timestamp_ms2 = custom_timestamp2 - config.custom_epoch

        expect(vin_id1.timestamp.milliseconds).to eq(expected_timestamp_ms1)
        expect(vin_id2.timestamp.milliseconds).to eq(expected_timestamp_ms2)
      end

      it "generates sequential IDs with increasing sequences" do
        # Generate multiple IDs with the same timestamp
        timestamps = [custom_timestamp, custom_timestamp, custom_timestamp]
        ids = subject.generate_ids_from_timestamps(data_type, timestamps: timestamps)

        expect(ids.length).to eq(3)
        expect(ids.uniq.length).to eq(3) # All IDs should be unique

        # Extract the VIN IDs
        vin_ids = ids.map { |id| VIN::Id.new(id: id, config: config) }

        # All should have the same timestamp
        expect(vin_ids.map { |v| v.timestamp.milliseconds }.uniq.length).to eq(1)

        # Group by logical shard ID to check sequences
        by_shard = vin_ids.group_by(&:logical_shard_id)
        by_shard.each_value do |shard_ids|
          sequences = shard_ids.map(&:sequence)
          # Sequences within the same shard should be unique
          expect(sequences.uniq.length).to eq(sequences.length)
        end
      end
    end

    context "when requesting many IDs with the same timestamp" do
      it "generates all unique IDs" do
        count = 100
        timestamps = Array.new(count, custom_timestamp)
        ids = subject.generate_ids_from_timestamps(data_type, timestamps: timestamps)

        expect(ids.length).to eq(count)
        expect(ids.uniq.length).to eq(count) # All IDs should be unique

        # All should have the same timestamp
        vin_ids = ids.map { |id| VIN::Id.new(id: id, config: config) }
        expect(vin_ids.map { |v| v.timestamp.milliseconds }.uniq.length).to eq(1)
      end
    end
  end

  describe "timestamp conversion and epoch handling" do
    it "correctly converts Unix timestamp to custom epoch relative timestamp" do
      # The custom timestamp is in Unix milliseconds (absolute time)
      # The ID stores timestamp relative to custom epoch
      ids = subject.generate_ids_from_timestamps(data_type, timestamps: [custom_timestamp])
      vin_id = VIN::Id.new(id: ids.first, config: config)

      # The stored timestamp should be relative to custom epoch
      expected_relative_ms = custom_timestamp - config.custom_epoch
      expect(vin_id.timestamp.milliseconds).to eq(expected_relative_ms)

      # When converted back to Unix time, it should match the original
      unix_timestamp = vin_id.timestamp.milliseconds + config.custom_epoch
      expect(unix_timestamp).to eq(custom_timestamp)
    end

    it "produces the same Time object as IDs generated without custom timestamp" do
      # Generate an ID with a custom timestamp
      ids_with_timestamp = subject.generate_ids_from_timestamps(data_type, timestamps: [custom_timestamp])
      vin_id_with_timestamp = VIN::Id.new(id: ids_with_timestamp.first, config: config)

      # The Time object should represent the custom timestamp
      expected_time = Time.at(custom_timestamp / 1000.0)
      actual_time = vin_id_with_timestamp.timestamp.to_time

      # Allow for small differences due to millisecond precision
      expect(actual_time.to_i).to eq(expected_time.to_i)
      expect((actual_time.usec / 1000) - (expected_time.usec / 1000)).to be_between(-1, 1)
    end
  end
end
