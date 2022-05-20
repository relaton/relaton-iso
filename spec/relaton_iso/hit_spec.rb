RSpec.describe RelatonIso::Hit do
  context "sort weight" do
    it "Deleted" do
      hit = RelatonIso::Hit.new({ status: "Deleted" })
      expect(hit.sort_weight).to eq 3
    end

    it "other" do
      hit = RelatonIso::Hit.new({ status: nil })
      expect(hit.sort_weight).to eq 4
    end
  end

  describe "#pubid" do
    subject { described_class.new({ title: title }).pubid }

    let(:title) { "#{pubid} Geographic information — Metadata — Part 1: Fundamentals" }
    let(:pubid) { "ISO 19115-1:2014" }

    it "extracts pubid from title" do
      expect(subject.to_s).to eq(pubid)
    end
  end
end
