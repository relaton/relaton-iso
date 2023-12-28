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

    context "extracts pubid from title" do
      let(:title) do
        "ISO 19115-1:2014 Geographic information — Metadata — Part 1: Fundamentals"
      end
      let(:pubid) { "ISO 19115-1:2014" }
      it { expect(subject.to_s).to eq(pubid) }
    end

    context "fails to extract pubid from title" do
      let(:title) { "Geographic information — Metadata — Part 1: Fundamentals" }
      it {
        expect do
          subject
        end.to output(/Unable to find an identifier/).to_stderr_from_any_process
      }
    end
  end
end
