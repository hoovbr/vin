describe VIN::Generator do
  include DummyData

  subject { described_class.new(config: config).generate_ids(data_type, count) }

  let(:config) { VIN::Config.new }
  let(:data_type) { random_data_type }
  let(:count) { 1 }
  let(:sequence_start) { 99 }
  let(:logical_shard_id) { random_logical_shard_id }
  let(:now) { DateTime.new(2023, 0o11, 0o15).to_time }
  let(:redis_response) do
    dummy_redis_response(
      count:,
      sequence_start:,
      logical_shard_id:,
      now:,
    )
  end
  let(:response) { VIN::Response.new(redis_response) }

  describe "#generate_ids" do
    context "with custom timestamp" do
      let(:custom_timestamp) { config.custom_epoch + 86_400_000 } # 1 day after custom epoch
      let(:generator) { described_class.new(config: config) }

      context "when timestamp is valid" do
        let(:request_double) { instance_double(VIN::Request) }

        before do
          allow(VIN::Request).to receive(:new).with(config, data_type, count, custom_timestamp: custom_timestamp).and_return(request_double)
          allow(request_double).to receive(:response).and_return(response)
        end

        it "validates timestamp is an integer" do
          expect do
            generator.generate_ids(data_type, count, timestamp: "not_a_number")
          end.to raise_error(ArgumentError, /timestamp must be an integer/)
        end

        it "validates timestamp is not before custom epoch" do
          expect do
            generator.generate_ids(data_type, count, timestamp: config.custom_epoch - 1000)
          end.to raise_error(ArgumentError, /timestamp cannot be before the custom epoch/)
        end
      end
    end

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

        it { expect(subject.length).to(be(6)) }
      end
    end
  end
end
