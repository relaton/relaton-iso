require "isobib/iso_bibliographic_item"

RSpec.describe Isobib::IsoBibliographicItem do
  it "create iso bibliographic item" do
    docid = Isobib::IsoDocumentId.new
    title = Isobib::IsoLocalizedTitle.new "Title intro", "Tile main", "en", "us"
    status = Isobib::LocalizedString.new "new status"
    iso_doc_status = Isobib::IsoDocumentStatus.new status,
      Isobib::IsoDocumentStageCodes::PREELIMINARY,
      Isobib::IsoDocumentSubstageCodes::REGISTRATION
      
    workgroup_name = Isobib::LocalizedString.new "new workgroup"
    techical_commite = Isobib::IsoSubgroup.new "new commite"
    workgroup = Isobib::IsoProjectGroup.new workgroup_name, techical_commite

    ics = Isobib::Ics.new
    iso_bib_item = Isobib::IsoBibliographicItem.new docid, title,
      Isobib::IsoDocumentType::INTERNATIONAL_STANDART, iso_doc_status, workgroup,
      ics

    expect(iso_bib_item.title.length).to be > 0
  end
end