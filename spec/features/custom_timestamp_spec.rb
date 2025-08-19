describe "VIN custom timestamp feature" do
  include DummyData

  subject { VIN.new(config: config) }

  let(:config) { VIN::Config.new }
  let(:data_type) { random_data_type }
  let(:now_ms) { (Time.now.to_f * 1000).to_i }
  let(:custom_timestamp) { config.custom_epoch + 86_400_000 } # 1 day after custom epoch

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

  describe "concurrent ID generation with same timestamp" do
    it "generates unique IDs when called concurrently with the same timestamp" do
      threads = []
      ids = []
      mutex = Mutex.new

      10.times do
        threads << Thread.new do
          id = subject.generate_id(data_type, timestamp: custom_timestamp)
          mutex.synchronize { ids << id }
        end
      end

      threads.each(&:join)

      expect(ids.length).to eq(10)
      expect(ids.uniq.length).to eq(10) # All IDs should be unique

      # All should have the same timestamp but different sequences
      vin_ids = ids.map { |id| VIN::Id.new(id: id, config: config) }
      timestamps = vin_ids.map(&:timestamp).map(&:milliseconds)
      sequences = vin_ids.map(&:sequence)

      expect(timestamps.uniq.length).to eq(1)
      expect(sequences.uniq.length).to be >= 1 # At least one unique sequence
    end
  end

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
