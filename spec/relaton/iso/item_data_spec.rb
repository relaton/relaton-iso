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

  context "#create_id" do
    context "with Pubid content" do
      it "sets id from the full identifier" do
        item = described_class.new(title: title, docidentifier: docid)
        item.create_id
        expect(item.id).to eq("ISO191152014")
      end

      it "excludes year when without_date is true" do
        item = described_class.new(title: title, docidentifier: docid)
        item.create_id(without_date: true)
        expect(item.id).to eq("ISO19115")
      end
    end

    context "with String content (failed parse)" do
      let(:string_docid) do
        [Relaton::Iso::Docidentifier.new(content: "FAKEID 12345:2014")]
      end

      before do
        allow(Pubid::Iso::Identifier).to receive(:parse)
          .with("FAKEID 12345:2014").and_raise(StandardError)
      end

      it "keeps the string as-is" do
        item = described_class.new(title: title, docidentifier: string_docid)
        item.create_id
        expect(item.id).to eq("FAKEID123452014")
      end

      it "strips trailing year when without_date is true" do
        item = described_class.new(title: title, docidentifier: string_docid)
        item.create_id(without_date: true)
        expect(item.id).to eq("FAKEID12345")
      end
    end
  end
end
