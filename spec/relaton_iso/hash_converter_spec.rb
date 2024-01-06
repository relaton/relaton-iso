describe RelatonIso::HashConverter do
  it "creates document identifier" do
    args = { id: "ISO 123", type: "ISO", primary: true }
    docid = RelatonIso::HashConverter.create_docid(**args)
    expect(docid).to be_instance_of RelatonIso::DocumentIdentifier
    expect(docid.instance_variable_get(:@id)).to be_instance_of Pubid::Iso::Identifier::InternationalStandard
    expect(docid.id).to eq "ISO 123"
    expect(docid.type).to eq "ISO"
    expect(docid.primary).to be true
  end
end
