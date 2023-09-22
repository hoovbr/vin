# frozen_string_literal: true

require "spec_helper"
include DummyData

describe VIN::Response do
  subject { described_class.new(redis_response) }

  let(:count) { 1 }
  let(:logical_shard_id) { random_logical_shard_id }
  let(:now) { Time.now }
  let(:redis_response) { dummy_redis_response(count:, logical_shard_id:, now:) }

  describe "#sequence" do
    context "when count is 1" do
      it { expect(subject.sequence.count).to(be(1)) }
      it { expect(subject.sequence).to(eql(subject.start_sequence..subject.end_sequence)) }
    end

    context "when count is 2" do
      let(:count) { 2 }

      it { expect(subject.sequence.count).to(be(2)) }
      it { expect(subject.sequence).to(eql(subject.start_sequence..subject.end_sequence)) }
    end
  end

  describe "#start_sequence" do
    context "when count is 1" do
      it { expect(subject.start_sequence).to(eql(subject.end_sequence)) }
    end

    context "when count is 3" do
      let(:count) { 3 }

      it { expect(subject.start_sequence).to(eql(subject.end_sequence - 2)) }
    end
  end

  describe "#end_sequence" do
    context "when count is 1" do
      it { expect(subject.end_sequence).to(eql(subject.start_sequence)) }
    end

    context "when count is 4" do
      let(:count) { 4 }

      it { expect(subject.end_sequence).to(eql(subject.start_sequence + 3)) }
    end
  end

  describe "#logical_shard_id" do
    it { expect(subject.logical_shard_id).to(eql(logical_shard_id)) }
  end

  describe "#seconds" do
    it { expect(subject.seconds).to(eql(now.to_i)) }
  end

  describe "#microseconds_part" do
    it { expect(subject.microseconds_part).to(eql(now.usec)) }
  end
end
