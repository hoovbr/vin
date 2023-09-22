# frozen_string_literal: true

require "spec_helper"

describe VIN::Config do
  subject { described_class.new }

  describe "#logical_shard_id_range" do
    context "when env vars are outside the valid range" do
      before do
        allow(ENV).to(receive(:fetch).and_call_original)
        allow(ENV).to(receive(:fetch).with("VIN_LOGICAL_SHARD_ID_RANGE_MIN").and_return("0"))
        allow(ENV).to(receive(:fetch).with("VIN_LOGICAL_SHARD_ID_RANGE_MAX").and_return("99"))
      end

      after do
        allow(ENV).to(receive(:fetch).and_call_original)
      end

      it { expect { subject }.to(raise_error(ArgumentError)) }
    end
  end
end
