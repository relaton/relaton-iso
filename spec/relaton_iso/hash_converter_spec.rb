describe RelatonIso::HashConverter do
  context "create_docid" do
    it "create pubid" do
      args = { id: "ISO 123", type: "ISO", primary: true }
      docid = RelatonIso::HashConverter.create_docid(**args)
      expect(docid).to be_instance_of RelatonIso::DocumentIdentifier
      expect(docid.instance_variable_get(:@id)).to be_instance_of Pubid::Iso::Identifier::InternationalStandard
      expect(docid.id).to eq "ISO 123"
      expect(docid.type).to eq "ISO"
      expect(docid.primary).to be true
    end

    it "don't create pubid" do
      args = { id: "ISO 123", type: "ISO" }
      docid = RelatonIso::HashConverter.create_docid(**args)
      expect(docid).to be_instance_of RelatonIso::DocumentIdentifier
      expect(docid.instance_variable_get(:@id)).to eq "ISO 123"
      expect(docid.type).to eq "ISO"
      expect(docid.primary).to be nil
    end

    it "warns if unable to create document identifier" do
      expect do
        described_class.create_docid(id: "ISO123", type: "ISO", primary: true)
      end.to output(/\[relaton-iso\] Unable to create a Pubid::Iso::Identifier from `ISO123`/).to_stderr_from_any_process
    end
  end
end
