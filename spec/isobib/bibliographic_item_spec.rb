require "isobib/bibliographic_item"

RSpec.describe Isobib::BibliographicItem do
  it "create bibliographic item" do
    bib_item = Isobib::BibliographicItem.new
    expect(bib_item.title.is_a? Array).to be_truthy

    from = DateTime.now
    owner = Isobib::Contributor.new
    copyright = Isobib::CopyrightAssociation.new from, owner
    bib_item.copyright = copyright
    expect(bib_item.copyright.is_a? Isobib::CopyrightAssociation).to be_truthy

    docid = Isobib::DocumentIdentifier.new "docid"
    bib_item.add_docidentifier docid
    expect(bib_item.docidentifier.length).to eq 1
  end
end