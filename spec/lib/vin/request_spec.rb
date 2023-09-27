# frozen_string_literal: true

describe VIN::Request do
  include DummyData

  subject { described_class.new(config, data_type, count) }

  let(:config) { VIN::Config.new }
  let(:data_type) { random_data_type }
  let(:count) { 1 }
  let(:lua_script) { 'return "Hello World!"' }
  let(:keys) { [data_type, count] }

  describe ".new" do
    context "when data_type is not a number" do
      let(:data_type) { nil }

      it { expect { subject }.to(raise_error(ArgumentError)) }
    end

    context "when data_type is a negative number" do
      let(:data_type) { -1 }

      it { expect { subject }.to(raise_error(ArgumentError)) }
    end

    context "when data_type is outside the allowed range" do
      let(:data_type) { config.max_data_type + 1 }

      it { expect { subject }.to(raise_error(ArgumentError)) }
    end

    context "when data_type is within the allowed range" do
      let(:data_type) { random_data_type }

      it { expect { subject }.not_to(raise_error) }
    end

    context "when count is not a number" do
      let(:count) { nil }

      it { expect { subject }.to(raise_error(ArgumentError)) }
    end

    context "when count is zero" do
      let(:count) { 0 }

      it { expect { subject }.to(raise_error(ArgumentError)) }
    end

    context "when count is a negative number" do
      let(:count) { -1 }

      it { expect { subject }.to(raise_error(ArgumentError)) }
    end

    context "when count is a positive number" do
      let(:count) { 1 }

      it { expect { subject }.not_to(raise_error) }
    end
  end

  # Deferring fixing these warnings until a later point.
  # rubocop:disable RSpec/SubjectStub
  describe "#response" do
    context "when no error is raised" do
      let(:redis_client) { double }

      it "response should be of type VIN::Response" do
        allow(subject).to receive_messages(redis: redis_client, lua_script_sha: "dummysha")
        allow(redis_client).to(receive(:evalsha).with("dummysha", keys:).and_return(dummy_redis_response(count:)))
        expect(subject.response).to(be_a(VIN::Response))
      end

      context "when count is one" do
        it { expect(subject.response.sequence.count).to(be(1)) }
      end

      context "when count is 5" do
        let(:count) { 5 }

        it { expect(subject.response.sequence.count).to(be(5)) }
      end
    end

    context "when a Redis::CommandError is raised" do
      it "tries up to 5 times" do
        # Deferring fixing this warning until a later point.
        # rubocop:disable RSpec/MessageSpies
        expect(subject).to(receive(:redis_response).exactly(5).times.and_raise(Redis::CommandError))
        expect { subject.response }.to(raise_error(Redis::CommandError))
        # rubocop:enable RSpec/MessageSpies
      end
    end
  end
  # rubocop:enable RSpec/SubjectStub
end
