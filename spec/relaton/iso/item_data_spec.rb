describe Relaton::Iso::ItemData do
  let(:title) { [Relaton::Bib::Title.new(content: "Title")] }
  let(:docid) { [Relaton::Iso::Docidentifier.new(content: "ISO 19115:2014")] }
  let(:note) { [Relaton::Bib::Note.new(content: "Note")] }

  subject do
    described_class.new(
      title: title,
      docidentifier: docid,
      note: note,
    )
  end

  context "#to_xml" do
    context "with empty initial notes" do
      subject { described_class.new(title: title, docidentifier: docid) }

      it "renders XML with only additional notes" do
        xml = subject.to_xml(note: [{ content: "Additional Note", type: "additional" }])
        expect(xml).to include("<note type=\"additional\">Additional Note</note>")
      end
    end

    it "renders XML with notes" do
      xml = subject.to_xml(note: [{ content: "Additional Note", type: "additional" }])
      expect(xml).to include("<note type=\"additional\">Additional Note</note>")
    end
  end

  context "#to_yaml" do
    it "renders YAML with notes" do
      yaml = subject.to_yaml(note: [{ content: "Additional Note", type: "additional" }])
      expect(yaml).to include("type: additional")
      expect(yaml).to include("- content: Additional Note")
    end
  end

  context "#to_json" do
    it "renders JSON with notes" do
      json = subject.to_json(note: [{ content: "Additional Note", type: "additional" }])
      expect(json).to include('"type":"additional"')
      expect(json).to include('"content":"Additional Note"')
    end
  end
end
