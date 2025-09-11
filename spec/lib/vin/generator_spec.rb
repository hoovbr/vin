describe VIN::Generator do
  include DummyData

  let(:config) { VIN::Config.new }
  let(:data_type) { random_data_type }
  let(:sequence_start) { 99 }
  let(:logical_shard_id) { random_logical_shard_id }
  let(:now) { DateTime.new(2023, 0o11, 0o15).to_time }
  let(:redis_response) do
    dummy_redis_response(
      count: 1,
      sequence_start:,
      logical_shard_id:,
      now:,
    )
  end
  let(:response) { VIN::Response.new(redis_response) }
  let(:generator) { described_class.new(config: config) }

  describe "#generate_id" do
    let(:request_double) { instance_double(VIN::Request) }

    before do
      allow(VIN::Request).to receive(:new).and_return(request_double)
      allow(request_double).to receive(:response).and_return(response)
    end

    it "generates a single ID" do
      result = generator.generate_id(data_type)
      expect(result).to be_a(Integer)
    end

    context "when data_type is invalid" do
      it "raises error when not an integer" do
        expect { generator.generate_id("foo") }.to raise_error(ArgumentError)
      end

      it "raises error when outside allowed range" do
        expect { generator.generate_id(config.max_data_type + 1) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#generate_ids" do
    subject { generator.generate_ids(data_type, count) }

    let(:count) { 1 }

    context "when arguments are invalid" do
      context "when data_type is not an integer" do
        let(:data_type) { "foo" }

        it { expect { subject }.to(raise_error(ArgumentError)) }
      end

      context "when data_type is less than 0" do
        let(:data_type) { -1 }

        it { expect { subject }.to(raise_error(ArgumentError)) }
      end

      context "when data_type is over the max" do
        let(:data_type) { config.max_data_type + 1 }

        it { expect { subject }.to(raise_error(ArgumentError)) }
      end

      context "when count is not an integer" do
        let(:count) { "bar" }

        it { expect { subject }.to(raise_error(ArgumentError)) }
      end

      context "when count is a negative number" do
        let(:count) { -1 }

        it { expect { subject }.to(raise_error(ArgumentError)) }
      end
    end

    context "when arguments are valid" do
      let(:request_double) { instance_double(VIN::Request) }

      before do
        allow(VIN::Request).to receive(:new).and_return(request_double)
        allow(request_double).to receive(:response).and_return(response)
      end

      context "when count is 1" do
        let(:id) { VIN::Id.new(id: subject.first, config: config) }
        let(:logical_shard_id) { 1 }
        let(:data_type) { 0 }

        it { expect(subject.length).to(be(1)) }
        it { expect(subject.first).to(be(406_035_470_746_648_675)) }
        it { expect(id.sequence).to(be(99)) }
        it { expect(id.data_type).to(eql(data_type)) }
        it { expect(id.logical_shard_id).to(eql(logical_shard_id)) }
        it { expect(id.timestamp.to_time).to(eql(now)) }
      end

      context "when count is 6" do
        let(:count) { 6 }
        let(:redis_response) do
          dummy_redis_response(
            count:,
            sequence_start:,
            logical_shard_id:,
            now:,
          )
        end

        it { expect(subject.length).to(be(6)) }
      end
    end
  end

  describe "#generate_ids_from_timestamps" do
    let(:one_day_after_epoch) { config.custom_epoch + 86_400_000 } # 1 day after custom epoch
    let(:two_days_after_epoch) { config.custom_epoch + 172_800_000 } # 2 days after custom epoch
    let(:three_days_after_epoch) { config.custom_epoch + 259_200_000 } # 3 days after custom epoch

    context "when timestamps array is provided" do
      let(:timestamps) { [one_day_after_epoch, two_days_after_epoch, three_days_after_epoch] }

      it "generates IDs for each timestamp" do
        request_double1 = instance_double(VIN::Request)
        request_double2 = instance_double(VIN::Request)
        request_double3 = instance_double(VIN::Request)

        response1 = VIN::Response.new(dummy_redis_response(count: 1, sequence_start: 100, logical_shard_id: 1, now: Time.at(one_day_after_epoch / 1000.0)))
        response2 = VIN::Response.new(dummy_redis_response(count: 1, sequence_start: 200, logical_shard_id: 2, now: Time.at(two_days_after_epoch / 1000.0)))
        response3 = VIN::Response.new(dummy_redis_response(count: 1, sequence_start: 300, logical_shard_id: 3, now: Time.at(three_days_after_epoch / 1000.0)))

        allow(VIN::Request).to receive(:new).with(config, data_type, 1, custom_timestamp: one_day_after_epoch).and_return(request_double1)
        allow(VIN::Request).to receive(:new).with(config, data_type, 1, custom_timestamp: two_days_after_epoch).and_return(request_double2)
        allow(VIN::Request).to receive(:new).with(config, data_type, 1, custom_timestamp: three_days_after_epoch).and_return(request_double3)

        allow(request_double1).to receive(:response).and_return(response1)
        allow(request_double2).to receive(:response).and_return(response2)
        allow(request_double3).to receive(:response).and_return(response3)

        result = generator.generate_ids_from_timestamps(data_type, timestamps: timestamps)

        expect(result.length).to eq(3)
        expect(result).to all(be_a(Integer))
      end

      it "maintains order of timestamps in results" do
        timestamps_shuffled = [three_days_after_epoch, one_day_after_epoch, two_days_after_epoch]

        request_doubles = {}
        responses = {}

        [one_day_after_epoch, two_days_after_epoch, three_days_after_epoch].each_with_index do |ts, i|
          request_double = instance_double(VIN::Request)
          request_doubles[ts] = request_double
          responses[ts] = VIN::Response.new(dummy_redis_response(
                                              count: timestamps_shuffled.count(ts),
                                              sequence_start: (i + 1) * 100,
                                              logical_shard_id: i + 1,
                                              now: Time.at(ts / 1000.0),
                                            ))

          allow(VIN::Request).to receive(:new).with(config, data_type, timestamps_shuffled.count(ts), custom_timestamp: ts).and_return(request_double)
          allow(request_double).to receive(:response).and_return(responses[ts])
        end

        result = generator.generate_ids_from_timestamps(data_type, timestamps: timestamps_shuffled)

        expect(result.length).to eq(3)
        
        # Results should be in the order of input timestamps
        # Verify each ID has the timestamp corresponding to its position
        vin_ids = result.map { |id| VIN::Id.new(id: id, config: config) }
        
        # First ID should have three_days_after_epoch
        expect(vin_ids[0].timestamp.milliseconds).to eq(three_days_after_epoch - config.custom_epoch)
        # Second ID should have one_day_after_epoch  
        expect(vin_ids[1].timestamp.milliseconds).to eq(one_day_after_epoch - config.custom_epoch)
        # Third ID should have two_days_after_epoch
        expect(vin_ids[2].timestamp.milliseconds).to eq(two_days_after_epoch - config.custom_epoch)
      end

      it "optimizes Redis calls for duplicate timestamps" do
        timestamps_with_duplicates = [one_day_after_epoch, two_days_after_epoch, one_day_after_epoch, three_days_after_epoch, two_days_after_epoch]

        # Expect only 3 unique Redis calls despite 5 timestamps
        request_double1 = instance_double(VIN::Request)
        request_double2 = instance_double(VIN::Request)
        request_double3 = instance_double(VIN::Request)

        # Response for one_day_after_epoch should have count=2 (two occurrences)
        response1 = VIN::Response.new(dummy_redis_response(count: 2, sequence_start: 100, logical_shard_id: 1, now: Time.at(one_day_after_epoch / 1000.0)))
        # Response for two_days_after_epoch should have count=2 (two occurrences)
        response2 = VIN::Response.new(dummy_redis_response(count: 2, sequence_start: 200, logical_shard_id: 2, now: Time.at(two_days_after_epoch / 1000.0)))
        # Response for three_days_after_epoch should have count=1 (one occurrence)
        response3 = VIN::Response.new(dummy_redis_response(count: 1, sequence_start: 300, logical_shard_id: 3, now: Time.at(three_days_after_epoch / 1000.0)))

        allow(VIN::Request).to receive(:new).with(config, data_type, 2, custom_timestamp: one_day_after_epoch).and_return(request_double1)
        allow(VIN::Request).to receive(:new).with(config, data_type, 2, custom_timestamp: two_days_after_epoch).and_return(request_double2)
        allow(VIN::Request).to receive(:new).with(config, data_type, 1, custom_timestamp: three_days_after_epoch).and_return(request_double3)

        allow(request_double1).to receive(:response).and_return(response1)
        allow(request_double2).to receive(:response).and_return(response2)
        allow(request_double3).to receive(:response).and_return(response3)

        result = generator.generate_ids_from_timestamps(data_type, timestamps: timestamps_with_duplicates)

        expect(result.length).to eq(5)
        # Should only make 3 Redis calls (one per unique timestamp)
        expect(VIN::Request).to have_received(:new).exactly(3).times
      end

      it "validates all timestamps in array" do
        invalid_timestamps = [one_day_after_epoch, "not_a_number", three_days_after_epoch]

        expect do
          generator.generate_ids_from_timestamps(data_type, timestamps: invalid_timestamps)
        end.to raise_error(ArgumentError, /timestamp must be an integer/)
      end

      it "validates no timestamp is before custom epoch" do
        invalid_timestamps = [one_day_after_epoch, config.custom_epoch - 1000, three_days_after_epoch]

        expect do
          generator.generate_ids_from_timestamps(data_type, timestamps: invalid_timestamps)
        end.to raise_error(ArgumentError, /timestamp cannot be before the custom epoch/)
      end
    end

    context "with empty timestamp array" do
      it "raises error for empty array" do
        expect do
          generator.generate_ids_from_timestamps(data_type, timestamps: [])
        end.to raise_error(ArgumentError, /timestamps array cannot be empty/)
      end
    end

    context "when timestamps exceed max_sequence for the same value" do
      it "raises error when requesting more than max_sequence IDs for the same timestamp" do
        # Create an array with more than max_sequence identical timestamps
        # Default max_sequence is 2047 (2^11 - 1)
        identical_timestamps = [one_day_after_epoch] * (config.max_sequence + 1)
        
        expect do
          generator.generate_ids_from_timestamps(data_type, timestamps: identical_timestamps)
        end.to raise_error(ArgumentError, /Cannot generate 2048 IDs for the same timestamp.*Maximum allowed is 2047/)
      end

      it "allows exactly max_sequence identical timestamps" do
        # This should work fine - exactly at the limit
        identical_timestamps = [one_day_after_epoch] * config.max_sequence
        
        # Mock the request/response to avoid actual Redis calls
        request_double = instance_double(VIN::Request)
        response_double = instance_double(VIN::Response, 
          sequence: (0...config.max_sequence).to_a,
          logical_shard_id: 1,
          seconds: 1234567890,
          microseconds_part: 123456
        )
        
        allow(VIN::Request).to receive(:new).and_return(request_double)
        allow(request_double).to receive(:response).and_return(response_double)
        
        expect do
          generator.generate_ids_from_timestamps(data_type, timestamps: identical_timestamps)
        end.not_to raise_error
      end
    end

    context "with single element timestamp array" do
      let(:timestamps) { [one_day_after_epoch] }

      it "generates one ID" do
        request_double = instance_double(VIN::Request)
        response = VIN::Response.new(dummy_redis_response(count: 1, sequence_start: 100, logical_shard_id: 1, now: Time.at(one_day_after_epoch / 1000.0)))

        allow(VIN::Request).to receive(:new).with(config, data_type, 1, custom_timestamp: one_day_after_epoch).and_return(request_double)
        allow(request_double).to receive(:response).and_return(response)

        result = generator.generate_ids_from_timestamps(data_type, timestamps: timestamps)

        expect(result.length).to eq(1)
        expect(result.first).to be_a(Integer)
      end
    end

    it "validates timestamps is an array" do
      expect do
        generator.generate_ids_from_timestamps(data_type, timestamps: "not_an_array")
      end.to raise_error(ArgumentError, /timestamps must be an array/)
    end
  end
end
