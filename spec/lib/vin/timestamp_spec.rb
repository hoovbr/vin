# frozen_string_literal: true

describe VIN::Timestamp do
  subject { described_class.new(milliseconds, epoch:) }

  let(:now) { Time.now }
  let(:milliseconds) { (now.to_f * 1_000).floor }
  let(:epoch) { (DateTime.new(now.year, 1, 1).to_time.to_f * 1_000).floor }

  describe "#milliseconds" do
    it { expect(subject.milliseconds).to(eql(milliseconds)) }
  end

  describe "#epoch" do
    it { expect(subject.epoch).to(eql(epoch)) }
  end

  describe "#seconds" do
    it { expect(subject.seconds).to(eql((milliseconds / 1_000).floor)) }
  end

  describe "#microseconds_part" do
    let(:milliseconds) { 1_491_177_600_000 + 42 }

    it { expect(subject.microseconds_part).to(be(42_000)) }
  end

  describe "#to_i" do
    it { expect(subject.to_i).to(eql(milliseconds)) }
  end

  describe "#to_time" do
    context "with unix epoch" do
      let(:milliseconds) { 1_491_177_600_000 }
      let(:epoch) { 0 }

      it { expect(subject.to_time).to(eql(DateTime.new(2017, 0o4, 0o3).to_time)) }
    end

    context "with custom epoch" do
      let(:milliseconds) { 7_948_800_000 }
      let(:epoch) { 1_483_228_800_000 }

      it { expect(subject.to_time).to(eql(DateTime.new(2017, 0o4, 0o3).to_time)) }
    end
  end

  describe "#with_unix_epoch" do
    context "when epoch is already unix" do
      let(:milliseconds) { 1_491_177_600_000 }
      let(:epoch) { 0 }

      it { expect(subject.with_unix_epoch.milliseconds).to(eql(milliseconds)) }
    end

    context "when epoch is custom" do
      let(:milliseconds) { 7_948_800_000 }
      let(:epoch) { 1_483_228_800_000 }

      it { expect(subject.with_unix_epoch.milliseconds).to(be(1_491_177_600_000)) }
    end
  end

  describe "#with_epoch" do
    context "when epoch is unix" do
      let(:epoch) { 0 }

      context "when new epoch is unix" do
        let(:new_epoch) { 0 }

        it { expect(subject.with_epoch(new_epoch).milliseconds).to(eql(milliseconds)) }
      end

      context "when new epoch is custom" do
        let(:new_epoch) { 1_451_606_400_000 }

        it { expect(subject.with_epoch(new_epoch).to_time.to_i).to(eql(now.to_i)) }
      end
    end

    context "when epoch is custom" do
      let(:milliseconds) { 7_948_800_000 }
      let(:epoch) { 1_483_228_800_000 }

      it { expect(subject.with_unix_epoch.milliseconds).to(be(1_491_177_600_000)) }
    end
  end

  describe ".from_reids" do
    subject { described_class.from_redis(seconds, microseconds_part) }

    let(:seconds) { 7_948_800 }
    let(:microseconds_part) { 42_000 }

    it { expect(subject.milliseconds).to(be(7_948_800_042)) }
  end
end
