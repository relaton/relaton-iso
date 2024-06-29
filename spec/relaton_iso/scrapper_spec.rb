# encoding: UTF-8

RSpec.describe RelatonIso::Scrapper do
  let(:doc) do
    Nokogiri::HTML File.read "spec/fixtures/iso_123.html", encoding: "UTF-8"
  end

  let(:pubid) { Pubid::Iso::Identifier.parse("ISO 123-1:2001") }

  it "parse page" do
    expect(described_class).to receive(:get_page).with("1234").and_return [doc, "url"]
    expect(described_class).to receive(:fetch_titles_abstract).with(doc, "en")
      .and_return [:title, :abstract, [{ lang: "en" }]]
    expect(described_class).to receive(:fetch_relaton_docids)
      .with(doc, kind_of(Pubid::Iso::Identifier::InternationalStandard)).and_return :docid
    expect(described_class).to receive(:fetch_docnumber)
      .with(kind_of(Pubid::Iso::Identifier::InternationalStandard)).and_return :docnum
    expect(described_class).to receive(:fetch_type).with("ISO 123:2001").and_return :type
    expect(described_class).to receive(:fetch_status).with(doc).and_return :status
    expect(described_class).to receive(:fetch_ics).with(doc).and_return :ics
    expect(described_class).to receive(:fetch_dates).with(doc, "ISO 123:2001").and_return :date
    expect(described_class).to receive(:fetch_contributors).with("ISO 123:2001").and_return :contrib
    expect(described_class).to receive(:fetch_workgroup).with(doc).and_return :wg
    expect(described_class).to receive(:fetch_copyright).with(doc).and_return :copyright
    expect(described_class).to receive(:fetch_link).with(doc, "url").and_return :link
    expect(described_class).to receive(:fetch_relations).with(doc).and_return :relations
    expect(described_class).to receive(:fetch_structuredidentifier)
      .with(kind_of(Pubid::Iso::Identifier::InternationalStandard)).and_return :si
    expect(RelatonIsoBib::IsoBibliographicItem).to receive(:new).with(
      docid: :docid, docnumber: :docnum, edition: "3", language: ["en"], script: ["Latn"], title: :title,
      doctype: :type, docstatus: :status, ics: :ics, date: :date, contributor: :contrib, editorialgroup: :wg,
      abstract: :abstract, copyright: :copyright, link: :link, relation: :relations,
      place: ["Geneva"], structuredidentifier: :si
    ).and_return :bib
    expect(described_class.parse_page("1234", "en")).to eq :bib
  end

  it "returns TS type" do
    doctype = RelatonIso::Scrapper.send(:fetch_type, "ISO/TS 123")
    expect(doctype).to be_instance_of RelatonIsoBib::DocumentType
    expect(doctype.type).to eq "technical-specification"
  end

  it "returns IWA type" do
    doctype = RelatonIso::Scrapper.send(:fetch_type, "IWA 123:2015")
    expect(doctype.type).to eq "international-workshop-agreement"
  end

  context "raises an error" do
    # let(:hit) { double "hit", hit: { path: "1234" } }

    # it "could not access" do
    #   expect(Net::HTTP).to receive(:get_response).and_raise(SocketError).exactly(4).times
    #   expect { RelatonIso::Scrapper.parse_page(hit) }.to raise_error RelatonBib::RequestError
    # end

    # it "not found" do
    #   resp = double
    #   expect(resp).to receive(:code).and_return("404").exactly(4).times
    #   expect(Net::HTTP).to receive(:get_response).and_return(resp).exactly(4).times
    #   expect do
    #     RelatonIso::Scrapper.parse_page(hit)
    #   end.to raise_error RelatonBib::RequestError
    # end
  end

  describe "#fetch_relaton_docids" do
    subject do
      expect(RelatonIso::Scrapper).to receive(:stage_code).and_return "90.93"
      described_class.fetch_relaton_docids(:doc, Pubid::Iso::Identifier.parse(pubid))
    end

    let(:source_pubid) { "ISO 19115:2003" }
    let(:pubid) { "ISO 19115:2003" }
    let(:isoref) { "ISO 19115:2003(E)" }
    let(:urn) { "urn:iso:std:iso:19115:stage-90.93" }
    let(:edition) { "3" }
    let(:stage) { 90.93 }

    it "returns PubID and URN RelatonBib document identifiers" do
      expect(subject.map(&:id)).to eq([pubid, isoref, urn])
    end
  end

  it "#isoref" do
    pubid = Pubid::Iso::Identifier.parse "ISO/DIS 14460"
    expect(subject.isoref(pubid)).to eq "ISO/DIS 14460(E)"
  end

  it "#fetch_titles_abstract" do
    expect(described_class).to receive(:get_page).with("/fr/standard/23281.html").and_return [doc, "url"]
    expect(described_class).to receive(:fetch_title).with(doc, "en").and_return double "title_en", titles: [:title_en]
    expect(described_class).to receive(:fetch_title).with(doc, "fr").and_return double "title_fr", titles: [:title_fr]
    expect(described_class).to receive(:parse_abstract).with(doc, { lang: "en" }).and_return :abstract_en
    expect(described_class).to receive(:parse_abstract).with(doc, { lang: "fr", path: "/fr/standard/23281.html" })
      .and_return :abstract_fr
    title, abstract, langs = described_class.send(:fetch_titles_abstract, doc, "en")
    expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
    expect(title.first).to eq :title_en
    expect(title.last).to eq :title_fr
    expect(abstract).to eq %i[abstract_en abstract_fr]
    expect(langs).to eq [{ lang: "en" }, { lang: "fr", path: "/fr/standard/23281.html" }]
  end

  it "#parce_abstract" do
    abstract = described_class.send(:parse_abstract, doc, { lang: "en" })
    expect(abstract[:content]).to include "This International Standard specifies procedures"
    expect(abstract[:language]).to eq "en"
    expect(abstract[:script]).to eq "Latn"
    expect(abstract[:format]).to eq "text/plain"
  end

  context "#get_page" do
    it "no error" do
      uri = double "uri", to_s: :url
      expect(described_class).to receive(:get_redirection).with("/path").and_return [:resp, uri]
      expect(described_class).to receive(:try_if_fail).with(:resp, uri).and_return :doc
      expect(described_class.send(:get_page, "/path")).to eq %i[doc url]
    end

    it "error" do
      expect(described_class).to receive(:get_redirection).with("/path").and_raise(SocketError).exactly(4).times
      expect { described_class.send(:get_page, "/path") }.to raise_error RelatonBib::RequestError
    end
  end

  context "#get_redirection" do
    before do
      expect(URI).to receive(:parse).with("#{RelatonIso::Scrapper::DOMAIN}/path").and_return :uri
    end
    it "found without redirection" do
      resp = double "response", code: "200"
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
      expect(described_class.send(:get_redirection, "/path")).to eq [resp, :uri]
    end

    it "found with redirection" do
      resp = double "response", code: "301"
      expect(resp).to receive(:[]).with("location").and_return "/new_path"
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
      expect(URI).to receive(:parse).with("#{RelatonIso::Scrapper::DOMAIN}/new_path").and_return :uri2
      resp2 = double "response 2", code: "200"
      expect(Net::HTTP).to receive(:get_response).with(:uri2).and_return resp2
      expect(described_class.send(:get_redirection, "/path")).to eq [resp2, :uri2]
    end

    it "not found" do
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return(double(code: "504")).exactly(4).times
      expect { described_class.send(:get_redirection, "/path") }.to raise_error RelatonBib::RequestError
    end

    context "retry" do
      let(:resp) { double(code: "200") }

      it do
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Errno::EPIPE).twice
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_return(resp)
        expect(described_class.send(:get_redirection, "/path")).to eq [resp, :uri]
      end

      it "limit" do
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Errno::EPIPE).exactly(3).times
        expect { described_class.send(:get_redirection, "/path") }.to raise_error Errno::EPIPE
      end
    end
  end

  context "#try_if_fail" do
    let(:resp) { double "response" }

    it "success" do
      expect(resp).to receive(:body).and_return(
        "<html><body></body></html>",
        "<html><body><main><div><section><div><div><div><nav><h1><span>ISO 123</span></h1>" \
          "</nav></div></div></div></section></div></main></body></html>",
      )
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
      doc = described_class.send(:try_if_fail, resp, :uri)
      expect(doc.at("h1").text).to eq "ISO 123"
    end

    it "fail" do
      expect(resp).to receive(:body).and_return("<html><body></body></html>").exactly(10).times
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return(resp).exactly(10).times
      expect do
        described_class.send(:try_if_fail, resp, :uri)
      end.to raise_error RelatonBib::RequestError
    end
  end

  it "#fetch_docnumber" do
    docnumber = described_class.send(:fetch_docnumber, pubid)
    expect(docnumber).to eq "123"
  end

  it "#fetch_structuredidentifier" do
    si = described_class.send(:fetch_structuredidentifier, pubid)
    expect(si).to be_instance_of RelatonIsoBib::StructuredIdentifier
    expect(si.project_number).to eq "ISO 123"
    expect(si.part).to eq "1"
    expect(si.type).to eq "ISO"
  end

  it "#fetch_status" do
    status = described_class.send(:fetch_status, doc)
    expect(status).to be_instance_of RelatonBib::DocumentStatus
    expect(status.stage.value).to eq "90"
    expect(status.substage.value).to eq "93"
  end

  it "#fetch_workgroup" do
    wg = described_class.send(:fetch_workgroup, doc)
    expect(wg).to be_instance_of RelatonIsoBib::EditorialGroup
    expect(wg.technical_committee).to be_instance_of Array
    expect(wg.technical_committee[0]).to be_instance_of RelatonBib::WorkGroup
    expect(wg.technical_committee[0].name).to eq "Raw materials (including latex) for use in the rubber industry"
    expect(wg.technical_committee[0].identifier).to eq "ISO/TC 45/SC 3"
    expect(wg.technical_committee[0].type).to eq "TC"
    expect(wg.technical_committee[0].number).to eq 45
  end

  it "#fetch_relations" do
    relations = described_class.send(:fetch_relations, doc)
    expect(relations).to be_instance_of Array
    expect(relations.size).to eq 1
    expect(relations.first[:type]).to eq "obsoletes"
    expect(relations.first[:bibitem]).to be_instance_of RelatonIsoBib::IsoBibliographicItem
    expect(relations.first[:bibitem].formattedref.content).to eq "ISO 123:1985"
    expect(relations.first[:bibitem].docidentifier.first.id).to eq "ISO 123:1985"
    expect(relations.first[:bibitem].docidentifier.first.type).to eq "ISO"
    expect(relations.first[:bibitem].docidentifier.first.primary).to be true
  end

  context "#relation_type" do
    it "obsoletes" do
      type_date = described_class.send(:relation_type, "Previously", doc)
      expect(type_date).to eq ["obsoletes", []]
    end

    it "obsoletes" do
      type_date = described_class.send(:relation_type, "Will be replaced by", doc)
      expect(type_date).to eq ["obsoletes", []]
    end

    it "updates" do
      type_date = described_class.send(:relation_type, "Corrigenda / Amendments", doc)
      expect(type_date).to eq ["updates", [{ on: "2021-06-07", type: "circulated" }]]
    end

    it "updates" do
      type_date = described_class.send(:relation_type, "Revised by", doc)
      expect(type_date).to eq ["updates", [{ on: "2021-06-07", type: "circulated" }]]
    end

    it "updates" do
      typed_date = described_class.send(:relation_type, "Now confirmed", doc)
      expect(typed_date).to eq ["updates", [{ on: "2021-06-07", type: "circulated" }]]
    end
  end

  context "#fetch_title" do
    it "intro, main, part" do
      doc = Nokogiri::HTML <<~HTML
        <h1 class="stdTitle">
          <span class="d-block mb-3 "><strike>ISO 19115-2:2009</strike></span>
          <span class="lead d-block mb-3">Geographic information — Metadata</span>
          <span class="lead d-block fw-semibold">Part 2: Extensions for imagery and gridded data</span>
        </h1>
      HTML
      title = described_class.send(:fetch_title, doc, "en")
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first.title.content).to eq "Geographic information"
      expect(title.first.type).to eq "title-intro"
      expect(title[1].title.content).to eq "Metadata"
      expect(title[1].type).to eq "title-main"
      expect(title[2].title.content).to eq "Part 2: Extensions for imagery and gridded data"
      expect(title[2].type).to eq "title-part"
      expect(title[3].title.content).to eq "Geographic information - Metadata - Part 2: Extensions for imagery and gridded data"
      expect(title[3].type).to eq "main"
    end

    it "intro, main" do
      doc = Nokogiri::HTML <<~HTML
        <h1 class="stdTitle">
          <span class="d-block mb-3 "><strike>ISO 19115-2:2009</strike></span>
          <span class="lead d-block mb-3">Geographic information</span>
          <span class="lead d-block fw-semibold">Metadata</span>
        </h1>
      HTML
      title = described_class.send(:fetch_title, doc, "en")
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first.title.content).to eq "Geographic information"
      expect(title.first.type).to eq "title-intro"
      expect(title[1].title.content).to eq "Metadata"
      expect(title[1].type).to eq "title-main"
      expect(title[2].title.content).to eq "Geographic information - Metadata"
      expect(title[2].type).to eq "main"
    end

    it "main" do
      doc = Nokogiri::HTML <<~HTML
        <h1 class="stdTitle">
          <span class="d-block mb-3 "><strike>ISO 19115-2:2009</strike></span>
          <span class="lead d-block mb-3">Geographic information</span>
        </h1>
      HTML
      title = described_class.send(:fetch_title, doc, "en")
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first.title.content).to eq "Geographic information"
      expect(title.first.type).to eq "title-main"
      expect(title[1].title.content).to eq "Geographic information"
      expect(title[1].type).to eq "main"
    end

    it "split single title" do
      doc = Nokogiri::HTML <<~HTML
        <h1 class="stdTitle">
          <span class="d-block mb-3 "><strike>ISO 19115-2:2009</strike></span>
          <span class="lead d-block mb-3">Geographic information — Metadata - Part 2: Extensions for imagery and gridded data</span>
        </h1>
      HTML
      title = described_class.send(:fetch_title, doc, "en")
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first.title.content).to eq "Geographic information"
      expect(title.first.type).to eq "title-intro"
      expect(title[1].title.content).to eq "Metadata"
      expect(title[1].type).to eq "title-main"
      expect(title[2].title.content).to eq "Part 2: Extensions for imagery and gridded data"
      expect(title[2].type).to eq "title-part"
      expect(title[3].title.content).to eq "Geographic information - Metadata - Part 2: Extensions for imagery and gridded data"
      expect(title[3].type).to eq "main"
    end
  end

  context "#fetch_dates" do
    it "published from doc" do
      dates = described_class.send(:fetch_dates, doc, "ISO 123:2001")
      expect(dates).to be_instance_of Array
      expect(dates.size).to eq 1
      expect(dates.first[:type]).to eq "published"
      expect(dates.first[:on]).to eq "2001-05"
    end

    it "published from doc when ID is undated" do
      dates = described_class.send(:fetch_dates, doc, "ISO 123")
      expect(dates).to be_instance_of Array
      expect(dates.size).to eq 1
      expect(dates.first[:type]).to eq "published"
      expect(dates.first[:on]).to eq "2001-05"
    end

    it "published & updated from doc" do
      expect(doc).to receive(:at).with("//span[@itemprop='releaseDate']").and_return double(text: "2002-06-07")
      allow(doc).to receive(:at).with("//span[@itemprop='dateModified']").and_call_original
      dates = described_class.send(:fetch_dates, doc, "ISO 123:2001")
      expect(dates.size).to eq 2
      expect(dates[0][:type]).to eq "published"
      expect(dates[0][:on]).to eq "2001"
      expect(dates[1][:type]).to eq "updated"
      expect(dates[1][:on]).to eq "2002-06-07"
    end

    it "from reference" do
      expect(doc).to receive(:at).with("//span[@itemprop='releaseDate']").and_return nil
      allow(doc).to receive(:at).with("//span[@itemprop='dateModified']").and_call_original
      dates = described_class.send(:fetch_dates, doc, "ISO 123:2001")
      expect(dates.size).to eq 1
      expect(dates[0][:type]).to eq "published"
      expect(dates[0][:on]).to eq "2001"
    end

    it "corrected" do
      expect(doc).to receive(:at).with("//span[@itemprop='releaseDate']").and_call_original
      expect(doc).to receive(:at).with("//span[@itemprop='dateModified']").and_return double(text: "2002-06-07")
      dates = described_class.send(:fetch_dates, doc, "ISO 123:2001")
      expect(dates.size).to eq 2
      expect(dates[1][:type]).to eq "corrected"
      expect(dates[1][:on]).to eq "2002-06-07"
    end
  end

  it "#fetch_contributors" do
    contrib = described_class.send(:fetch_contributors, "ISO 123:2001")
    expect(contrib).to be_instance_of Array
    expect(contrib.size).to eq 1
    expect(contrib.first[:entity][:abbreviation]).to eq "ISO"
    expect(contrib.first[:entity][:name]).to eq "International Organization for Standardization"
    expect(contrib.first[:entity][:url]).to eq "www.iso.org"
    expect(contrib.first[:role]).to eq [{ type: "publisher" }]
  end

  it "#fetch_ics" do
    ics = described_class.send(:fetch_ics, doc)
    expect(ics).to be_instance_of Array
    expect(ics.size).to eq 1
    expect(ics.first[:field]).to eq "83"
    expect(ics.first[:group]).to eq "040"
    expect(ics.first[:subgroup]).to eq "10"
  end

  it "#fetch_link" do
    pub = double "pub_ref"
    expect(pub).to receive(:"[]").with(:href).and_return "https://www.iso.org/standard/62510.html"
    expect(doc).to receive(:at).with(
      "//p[contains(., 'publicly available')]/a", "//p[contains(., 'can be downloaded from the')]/a"
    ).and_return pub
    allow(doc).to receive(:at).and_call_original
    link = described_class.send(:fetch_link, doc, "https://www.iso.org/standard/62510.html")
    expect(link).to be_instance_of Array
    expect(link.size).to eq 4
    expect(link.first[:type]).to eq "src"
    expect(link.first[:content]).to eq "https://www.iso.org/standard/62510.html"
    expect(link[1][:type]).to eq "obp"
    expect(link[1][:content]).to eq "https://www.iso.org/obp/ui/en/#!iso:std:23281:en"
    expect(link[2][:type]).to eq "rss"
    expect(link[2][:content]).to eq "https://www.iso.org/contents/data/standard/02/32/23281.detail.rss"
  end

  context "#fetch_copyright" do
    it "get date from ID" do
      expect(described_class.send(:fetch_copyright, doc)).to eq [{ from: "2001", owner: [{ name: "ISO" }]}]
    end

    it "parse date from doc" do
      expect(described_class).to receive(:item_ref).and_return "ISO 123"
      expect(described_class.send(:fetch_copyright, doc)).to eq [{ from: "2001", owner: [{ name: "ISO" }]}]
    end
  end
end
