RSpec.describe RelatonIso::DocumentIdentifier do
  let(:type) { "ISO" }

  subject do
    described_class.new(id: Pubid::Iso::Identifier.parse("ISO/TR 11071-2:1996"), type: type)
  end

  context "ISO" do
    it "set all parts" do
      subject.all_parts
      expect(subject.id).to eq "ISO/TR 11071-2:1996 (all parts)"
    end
  end

  context "URN" do
    let(:type) { "URN" }

    it "set all parts" do
      subject.all_parts
      expect(subject.id).to eq "urn:iso:std:iso:tr:11071:-2:ser"
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

  it "#to_h" do
    pubid_hash = subject.to_h
    expect(pubid_hash[:publisher]).to eq "ISO"
    expect(pubid_hash[:type]).to be :tr
    expect(pubid_hash[:number]).to eq "11071"
    expect(pubid_hash[:part]).to eq "2"
    expect(pubid_hash[:year]).to eq 1996
    expect(pubid_hash.key?(:edition)).to be false
  end
end
