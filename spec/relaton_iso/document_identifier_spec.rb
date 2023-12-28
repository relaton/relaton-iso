RSpec.describe RelatonIso::DocumentIdentifier do
  let(:type) { "ISO" }

  subject do
    described_class.new(id: Pubid::Iso::Identifier.parse("ISO 1111:2014"), type: type)
  end

  context "ISO" do
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

    it "handle NoEditionError" do
      pubid = described_class.new id: Pubid::Iso::Identifier.parse("ISO 1111/Amd"), type: type
      expect do
        pubid.id
      end.to output(
        /\[relaton-iso\] WARNING: URN identifier can't be generated for ISO 1111\/Amd: Base document must have edition/,
      ).to_stderr_from_any_process
    end
  end
end
