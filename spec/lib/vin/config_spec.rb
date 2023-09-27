# frozen_string_literal: true

describe VIN::Config do
  subject { described_class.new }

  describe "#logical_shard_id_range" do
    context "when env vars are provided and are outside the valid range" do
      before do
        allow(ENV).to(receive(:fetch).and_call_original)
        allow(ENV).to(receive(:fetch).with("VIN_LOGICAL_SHARD_ID_RANGE_MIN", anything).and_return("0"))
        allow(ENV).to(receive(:fetch).with("VIN_LOGICAL_SHARD_ID_RANGE_MAX", anything).and_return("99"))
      end

      after do
        allow(ENV).to(receive(:fetch).and_call_original)
      end

      it { expect { subject }.to(raise_error(ArgumentError)) }
    end

    context "when env vars for VIN_LOGICAL_SHARD_ID_RANGE_* are not provided" do
      before do
        allow(ENV).to(receive(:fetch).and_call_original)
        allow(ENV).to(receive(:fetch).with("VIN_LOGICAL_SHARD_ID_RANGE_MIN").and_return(nil))
        allow(ENV).to(receive(:fetch).with("VIN_LOGICAL_SHARD_ID_RANGE_MAX").and_return(nil))
      end

      after do
        allow(ENV).to(receive(:fetch).and_call_original)
      end

      it "does not raise and logical_shard_id_range should be equal to logical_shard_id_allowed_range" do
        expect { subject }.not_to(raise_error)
        expect(subject.logical_shard_id_range).to(be_a(Range))
        expect(subject.logical_shard_id_range).to(eq(subject.logical_shard_id_allowed_range))
      end
    end
  end
end
