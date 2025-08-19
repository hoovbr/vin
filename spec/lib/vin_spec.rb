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

    context "with custom timestamp" do
      let(:custom_timestamp) { 1_646_160_000_000 + 86_400_000 } # 1 day after custom epoch

      it "passes timestamp to generator" do
        allow(generator).to receive(:generate_ids).with(data_type, 1, timestamp: custom_timestamp).and_return(ids)
        subject.generate_id(data_type, timestamp: custom_timestamp)
        expect(generator).to have_received(:generate_ids).with(data_type, 1, timestamp: custom_timestamp)
      end
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

    context "with custom timestamp" do
      let(:custom_timestamp) { 1_646_160_000_000 + 86_400_000 } # 1 day after custom epoch
      let(:count) { 3 }

      it "passes timestamp to generator" do
        allow(generator).to receive(:generate_ids).with(data_type, count, timestamp: custom_timestamp).and_return(ids)
        subject.generate_ids(data_type, count, timestamp: custom_timestamp)
        expect(generator).to have_received(:generate_ids).with(data_type, count, timestamp: custom_timestamp)
      end

      it "passes timestamp on subsequent calls when more IDs are needed" do
        small_batch = [dummy_id]
        allow(generator).to receive(:generate_ids)
          .with(data_type, count, timestamp: custom_timestamp)
          .and_return(small_batch)
        allow(generator).to receive(:generate_ids)
          .with(data_type, count - small_batch.length, timestamp: custom_timestamp)
          .and_return(ids[0...(count - small_batch.length)])

        result = subject.generate_ids(data_type, count, timestamp: custom_timestamp)
        expect(result.length).to eq(count)
        expect(generator).to have_received(:generate_ids)
          .with(data_type, count, timestamp: custom_timestamp)
        expect(generator).to have_received(:generate_ids)
          .with(data_type, count - small_batch.length, timestamp: custom_timestamp)
      end
    end
  end
end
