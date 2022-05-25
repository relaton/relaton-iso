RSpec.describe RelatonIso::DocumentIdentifier do
  subject do
    described_class.new(id: Pubid::Iso::Identifier.parse("ISO 1111:2014"), type: type)
  end

  context "ISO" do
    let(:type) { "ISO" }

    it "set all parts" do
      subject.all_parts
      expect(subject.id).to eq "ISO 1111:2014 (all parts)"
    end
  end

  context "URN" do
    let(:type) { "URN" }

    it "set all parts" do
      subject.all_parts
      expect(subject.id).to eq "urn:iso:std:iso:1111:ser"
    end
  end
end
