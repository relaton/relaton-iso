require "relaton/iso/data_parser"

describe Relaton::Iso::DataParser do
  def build(overrides = {}, ref_index: {}, tc_index: {}, amend_index: {}, date_index: {})
    rec_overrides = overrides
    base = {
      "id" => 1,
      "deliverableType" => "IS",
      "supplementType" => nil,
      "reference" => "ISO 9001:2015",
      "title" => { "en" => "Quality management systems - Requirements" },
      "publicationDate" => "2015-09-01",
      "edition" => 5,
      "icsCode" => ["03.120.10"],
      "ownerCommittee" => "ISO/TC 176/SC 2",
      "currentStage" => 9092,
      "replaces" => nil,
      "replacedBy" => nil,
      "languages" => ["en"],
      "pages" => { "en" => 30 },
      "scope" => { "en" => "<p>Specifies requirements.</p>" },
    }
    described_class.new(
      base.merge(rec_overrides), ref_index, Hash.new(true),
      tc_index, amend_index, date_index,
    ).parse
  end

  it "parses a published international standard" do
    item = build(
      {},
      tc_index: { "ISO/TC 176/SC 2" => { "en" => "Quality management and quality assurance" } },
    )
    primary = item.docidentifier.find(&:primary)

    expect(primary.content.to_s).to eq "ISO 9001:2015"
    expect(item.docidentifier.find { |d| d.type == "iso-reference" }.content.to_s)
      .to eq "ISO 9001:2015(E)"
    expect(item.docidentifier.find { |d| d.type == "URN" }.content.to_s)
      .to match(/^urn:iso:std:iso:9001:.*stage-90\.92/)

    expect(item.title.map(&:content)).to include "Quality management systems"
    expect(item.date.first.type).to eq "published"
    expect(item.date.first.at.to_s).to eq "2015-09-01"
    expect(item.edition.content).to eq "5"

    status = item.status
    expect(status.stage.content).to eq "90"
    expect(status.substage.content).to eq "92"

    eg = item.contributor.find { |c| c.role.any? { |r| r.type == "author" } }
    sub = eg.organization.subdivision.first
    expect(sub.name.first.content).to eq "Quality management and quality assurance"
    expect(sub.identifier.first.content).to eq "ISO/TC 176/SC 2"

    src = item.source.find { |s| s.type == "src" }
    expect(src.content).to eq "https://www.iso.org/standard/1.html"
    obp = item.source.find { |s| s.type == "obp" }
    expect(obp.content).to eq "https://www.iso.org/obp/ui/en/#!iso:std:1:en"
    rss = item.source.find { |s| s.type == "rss" }
    expect(rss.content).to eq "https://www.iso.org/contents/data/standard/00/00/1.detail.rss"

    expect(item.ext.ics.first.code).to eq "03.120.10"
    expect(item.ext.doctype.content).to eq "international-standard"
  end

  it "parses a withdrawn legacy recommendation" do
    item = build({
      "reference" => "ISO/R 102:1959",
      "deliverableType" => "R",
      "currentStage" => 9599,
      "title" => { "en" => "Title missing" },
      "scope" => { "en" => nil },
      "icsCode" => nil,
      "ownerCommittee" => "ISO/TMBG",
    })
    expect(item.docidentifier.find(&:primary).content.to_s).to eq "ISO/R 102:1959"
    expect(item.status.stage.content).to eq "95"
    expect(item.status.substage.content).to eq "99"
    expect(item.ext.doctype.content).to eq "recommendation"
    expect(item.abstract).to be_empty
  end

  it "splits an em-dashed title into intro/main/part" do
    item = build({ "title" => {
      "en" => "Information processing systems — Computer graphics — Part 1: FORTRAN",
    } })

    types = item.title.map(&:type)
    contents = item.title.map(&:content)
    expect(types).to include "title-intro", "title-main", "title-part", "main"
    expect(contents).to include "Information processing systems"
    expect(contents).to include "Computer graphics"
    expect(contents).to include "Part 1: FORTRAN"
  end

  it "maps `replaces` -> obsoletes (the older predecessor) and " \
     "`replacedBy` -> obsoletedBy (the newer successor)" do
    item = build(
      { "replaces" => [42], "replacedBy" => [99] },
      ref_index: { 42 => "ISO 9001:2008", 99 => "ISO 9001:2026" },
    )

    obsoletes = item.relation.find { |r| r.type == "obsoletes" }
    obsoleted_by = item.relation.find { |r| r.type == "obsoletedBy" }

    expect(obsoletes.bibitem.docidentifier.first.content).to eq "ISO 9001:2008"
    expect(obsoleted_by.bibitem.docidentifier.first.content).to eq "ISO 9001:2026"
  end

  it "marks supplements listed in amend_index as `updatedBy` on the base" do
    item = build(
      { "reference" => "ISO 19115-2:2019" },
      amend_index: { "ISO 19115-2:2019" => ["ISO 19115-2:2019/Amd 1:2022"] },
    )

    amd = item.relation.find { |r| r.bibitem.docidentifier.first.content.to_s == "ISO 19115-2:2019/Amd 1:2022" }
    expect(amd).not_to be_nil
    expect(amd.type).to eq "updatedBy"
  end

  it "emits a forward `updates` relation from a supplement to its base" do
    item = build({
      "reference" => "ISO 19115-2:2019/Amd 1:2022",
      "supplementType" => "Amd",
    })

    upd = item.relation.find { |r| r.type == "updates" }
    expect(upd).not_to be_nil
    expect(upd.bibitem.docidentifier.first.content.to_s).to eq "ISO 19115-2:2019"
  end

  it "attaches `published` date to a related bibitem when date_index has the ref" do
    item = build(
      { "replacedBy" => [99] },
      ref_index: { 99 => "ISO 9001:2026" },
      date_index: { "ISO 9001:2026" => "2026-04-15" },
    )

    rel = item.relation.find { |r| r.type == "obsoletedBy" }
    expect(rel.bibitem.date.first.type).to eq "published"
    expect(rel.bibitem.date.first.at.to_s).to eq "2026-04-15"
  end

  it "leaves a related bibitem with no date when date_index lacks the ref" do
    item = build(
      { "replacedBy" => [99] },
      ref_index: { 99 => "ISO 9001:2026" },
      date_index: {},
    )

    rel = item.relation.find { |r| r.type == "obsoletedBy" }
    expect(rel.bibitem.date).to be_empty
  end

  it "emits French titles when title.fr is present" do
    item = build({ "title" => {
      "en" => "Vocabulary",
      "fr" => "Vocabulaire",
    } })
    expect(item.title.map { |t| t.language }.flatten).to include "fr"
  end

  it "maps deliverableType + supplementType to doctype" do
    expect(build({ "deliverableType" => "TS" }).ext.doctype.content).to eq "technical-specification"
    expect(build({ "deliverableType" => "TR" }).ext.doctype.content).to eq "technical-report"
    expect(build({ "supplementType" => "Amd" }).ext.doctype.content).to eq "amendment"
    expect(build({ "supplementType" => "Cor" }).ext.doctype.content).to eq "technical-corrigendum"
    expect(build({ "supplementType" => "Add" }).ext.doctype.content).to eq "addendum"
    expect(build({ "supplementType" => "Suppl" }).ext.doctype.content).to eq "supplement"
  end

  it "splits the rss URL path by zero-padded id (4- and 5-digit ids)" do
    big = build({ "id" => 72140 })
    expect(big.source.find { |s| s.type == "rss" }.content)
      .to eq "https://www.iso.org/contents/data/standard/07/21/72140.detail.rss"

    small = build({ "id" => 1214 })
    expect(small.source.find { |s| s.type == "rss" }.content)
      .to eq "https://www.iso.org/contents/data/standard/00/12/1214.detail.rss"
  end

  it "falls back to the committee reference when tc_index is missing the entry" do
    item = build({}, tc_index: {})
    sub = item.contributor
      .find { |c| c.role.any? { |r| r.type == "author" } }
      .organization.subdivision.first
    expect(sub.name.first.content).to eq "ISO/TC 176/SC 2"
    expect(sub.identifier.first.content).to eq "ISO/TC 176/SC 2"
  end

  it "skips invalid pubid gracefully" do
    item = described_class.new(
      { "id" => 1, "reference" => "GARBAGE", "title" => { "en" => "x" } },
      {},
      Hash.new(true),
    ).parse

    docid = item.docidentifier.find(&:primary)
    expect(docid.content).to eq "GARBAGE"
  end
end
