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
    subject { described_class.new(hit).pubid }

    context "extracts pubid from title" do
      let(:hit) { { id: { publisher: "ISO", number: "19115", part: "1", year: "2014" } } }
      let(:pubid) { "ISO 19115-1:2014" }
      it do
        expect(subject.to_s).to eq(pubid)
      end
    end

    context "fails to extract pubid from title" do
      let(:hit) { { id: { publisher: "ISO", number: "19115", type: "TYPE" } } }
      it {
        expect do
          subject
        end.to output(
          match(/\[relaton-iso\] Unable to create an identifier/).and(match(/\[relaton-iso\] cannot parse type TYPE/)),
        ).to_stderr_from_any_process
      }
    end
  end
end
