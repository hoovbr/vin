# frozen_string_literal: true

describe VIN do
  include DummyData

  subject { described_class.new }

  let(:data_type) { random_data_type }
  let(:generator) { subject.send(:generator) }

  describe ".generate_id" do
    let(:id) { dummy_id }
    let(:ids) { [id] }

    it "generates one ID" do
      allow(generator).to(receive(:generate_ids).and_return(ids))
      expect(subject.generate_id(data_type)).to(eql(id))
    end
  end

  describe ".generate_ids" do
    let(:count) { 1 }
    let(:ids) { count.times.map { dummy_id } }

    context "when count is one" do
      it "generates one ID" do
        allow(generator).to(receive(:generate_ids).and_return(ids))
        expect(subject.generate_ids(data_type, count)).to(eql(ids))
      end
    end

    context "when count is seven" do
      let(:count) { 7 }

      it "generates seven ID" do
        allow(generator).to(receive(:generate_ids).and_return(ids))
        expect(subject.generate_ids(data_type, count)).to(eql(ids))
      end
    end
  end
end
