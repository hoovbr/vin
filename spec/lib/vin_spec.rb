describe VIN do
  include DummyData

  subject { described_class.new }

  let(:data_type) { random_data_type }
  let(:generator) { subject.send(:generator) }

  describe ".generate_id" do
    let(:id) { dummy_id }

    it "generates one ID" do
      allow(generator).to(receive(:generate_id).and_return(id))
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

  describe ".generate_ids_from_timestamps" do
    let(:one_day_after_epoch) { 1_646_160_000_000 + 86_400_000 } # 1 day after custom epoch
    let(:two_days_after_epoch) { 1_646_160_000_000 + 172_800_000 } # 2 days after custom epoch
    let(:three_days_after_epoch) { 1_646_160_000_000 + 259_200_000 } # 3 days after custom epoch
    let(:timestamps) { [one_day_after_epoch, two_days_after_epoch, three_days_after_epoch] }
    let(:ids) { timestamps.map { dummy_id } }

    it "generates IDs for each timestamp" do
      allow(generator).to receive(:generate_ids_from_timestamps).with(data_type, timestamps: timestamps).and_return(ids)
      result = subject.generate_ids_from_timestamps(data_type, timestamps: timestamps)
      expect(result).to eql(ids)
      expect(result.length).to eq(timestamps.length)
    end

    it "passes timestamps to generator" do
      allow(generator).to receive(:generate_ids_from_timestamps).with(data_type, timestamps: timestamps).and_return(ids)
      subject.generate_ids_from_timestamps(data_type, timestamps: timestamps)
      expect(generator).to have_received(:generate_ids_from_timestamps).with(data_type, timestamps: timestamps)
    end
  end
end
