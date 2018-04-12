# frozen_string_literal: true

require 'isobib/bibliographic_item'

RSpec.describe Isobib::BibliographicItem do
  it 'create bibliographic item' do
    bib_item = Isobib::BibliographicItem.new
    expect(bib_item.title).to be_instance_of Array

    copyright = Isobib::CopyrightAssociation.new from:  '2014',
                                                 owner: { name: 'ISO' }
    bib_item.copyright = copyright
    expect(bib_item.copyright).to be_instance_of Isobib::CopyrightAssociation

    docid = Isobib::DocumentIdentifier.new 'docid'
    bib_item.add_docidentifier docid
    expect(bib_item.docidentifier.length).to eq 1
  end
end
