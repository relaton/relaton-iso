describe Relaton::Iso::Docidentifier do
  subject { described_class.new content: id, type: type }

  context "PRF" do
    let(:id) { "ISO/PRF TR 17716.2" }

    context "ISO" do
      let(:type) { "ISO" }
      it "should render PRF identifier" do
        expect(subject.to_s).to eq "ISO/PRF TR 17716.2"
      end
    end

    context "iso-reference" do
      let(:type) { "iso-reference" }
      it "should render PRF identifier" do
        expect(subject.to_s).to eq "ISO/PRF TR 17716.2(E)"
      end
    end

    context "URN" do
      let(:type) { "URN" }
      it "should render PRF identifier" do
        expect(subject.to_s).to eq "urn:iso:std:iso:tr:17716:stage-draft.v2"
      end
    end
  end

  context "#exclude_year" do
    let(:type) { "ISO" }

    it "removes year from a simple identifier" do
      docid = described_class.new content: "ISO 19115:2014", type: type
      result = docid.exclude_year
      expect(result.to_s).not_to include("2014")
      expect(result.to_s(with_prf: true)).to eq("ISO 19115")
    end

    it "removes year from identifier and its base" do
      docid = described_class.new content: "ISO 19115-1:2014/Amd 1:2018", type: type
      result = docid.exclude_year
      expect(result.to_s(with_prf: true)).to eq("ISO 19115-1/Amd 1")
    end
  end
end
