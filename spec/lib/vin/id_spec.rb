# frozen_string_literal: true

require "spec_helper"
include DummyData

describe VIN::Id do
  subject { described_class.new(id:, config:) }

  let(:config) { VIN::Config.new }
  let(:sequence) { 101 }
  let(:data_type) { random_data_type }
  let(:logical_shard_id) { random_logical_shard_id }
  let(:now) { Time.now }
  let(:id) { dummy_id(sequence:, data_type:, logical_shard_id:, now:) }

  describe "#id" do
    it { expect(subject.id).to(eql(id)) }
  end

  describe "#custom_timestamp" do
    it { expect(subject.custom_timestamp).to(eql((now.to_f * 1_000).floor - config.custom_epoch)) }
  end

  describe "#timestamp" do
    it { expect(subject.timestamp).to(be_a(VIN::Timestamp)) }
    it { expect(subject.timestamp.to_i).to(eql((now.to_f * 1_000).floor - config.custom_epoch)) }
    it { expect(subject.timestamp.epoch).to(eql(config.custom_epoch)) }
  end

  describe "#logical_shard_id" do
    it { expect(subject.logical_shard_id).to(eql(logical_shard_id)) }
  end

  describe "#data_type" do
    it { expect(subject.data_type).to(eql(data_type)) }
  end

  describe "#sequence" do
    it { expect(subject.sequence).to(eql(sequence)) }
  end
end
