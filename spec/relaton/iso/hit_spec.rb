RSpec.describe Relaton::Iso::Hit do
  context "sort weight" do
    it "Published" do
      hit = described_class.new({ status: "Published" })
      expect(hit.sort_weight).to eq 0
    end

    it "Under development" do
      hit = described_class.new({ status: "Under development" })
      expect(hit.sort_weight).to eq 1
    end

    it "Withdrawn" do
      hit = described_class.new({ status: "Withdrawn" })
      expect(hit.sort_weight).to eq 2
    end

    it "Deleted" do
      hit = described_class.new({ status: "Deleted" })
      expect(hit.sort_weight).to eq 3
    end

    it "other" do
      hit = described_class.new({ status: nil })
      expect(hit.sort_weight).to eq 4
    end
  end

  describe "#pubid" do
    subject { described_class.new(hit).pubid }

    context "create pubid from Hash" do
      let(:hit) { { id: { publisher: "ISO", number: "19115", part: "1", year: "2014" } } }
      let(:pubid) { "ISO 19115-1:2014" }
      it do
        expect(subject.to_s).to eq(pubid)
      end
    end

    context "fails to create pubid from Hash" do
      let(:hit) { { id: { publisher: "ISO", number: "19115", type: "TYPE" } } }
      it {
        expect do
          expect(subject).to be_nil
        end.to output(
          /\[relaton-iso\] WARN: Unable to create an identifier from {:publisher=>"ISO", :number=>"19115", :type=>"TYPE"}/,
        ).to_stderr_from_any_process
      }
    end
  end
end
