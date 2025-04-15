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
end
