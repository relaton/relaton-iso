# encoding: UTF-8

RSpec.describe RelatonIso::Scrapper do
  let(:doc) { Nokogiri::HTML File.read "spec/fixtures/iso_123.html", encoding: "UTF-8" }
  let(:doc_fr) { Nokogiri::HTML File.read "spec/fixtures/iso_123_fr.html", encoding: "UTF-8" }
  let(:errors) { Hash.new(true) }
  subject { described_class.new("en", errors) }
  let(:pubid) { Pubid::Iso::Identifier.parse("ISO 123-1:2001") }

  it "parse" do
    expect(subject).to receive(:get_page).with("1234").and_return [doc, "url"]
    expect(subject).to receive(:get_page).with("/fr/standard/23281.html").and_return [doc_fr, "url-fr"]
    bib = subject.parse("1234")
    expect(bib).to be_instance_of RelatonIsoBib::IsoBibliographicItem
    expect(bib.docidentifier.first).to be_instance_of RelatonIso::DocumentIdentifier
    expect(bib.docnumber).to eq "123"
    expect(bib.edition).to be_instance_of RelatonBib::Edition
    expect(bib.language).to eq ["en", "fr"]
    expect(bib.script).to eq ["Latn"]
    expect(bib.title).to be_instance_of RelatonBib::TypedTitleStringCollection
    expect(bib.doctype).to be_instance_of RelatonIsoBib::DocumentType
    expect(bib.status).to be_instance_of RelatonBib::DocumentStatus
    expect(bib.ics.first).to be_instance_of RelatonIsoBib::Ics
    expect(bib.date.first).to be_instance_of RelatonBib::BibliographicDate
    expect(bib.contributor.first).to be_instance_of RelatonBib::ContributionInfo
    expect(bib.editorialgroup).to be_instance_of RelatonIsoBib::EditorialGroup
    expect(bib.abstract.first).to be_instance_of RelatonBib::FormattedString
    expect(bib.copyright.first).to be_instance_of RelatonBib::CopyrightAssociation
    expect(bib.link.first).to be_instance_of RelatonBib::TypedUri
    expect(bib.relation.first).to be_instance_of RelatonBib::DocumentRelation
    expect(bib.place.first.name).to eq "Geneva"
    expect(bib.structuredidentifier).to be_instance_of RelatonIsoBib::StructuredIdentifier
  end

  it "returns TS type" do
    subject.instance_variable_set :@id, "ISO/TS 123"
    doctype = subject.send(:fetch_type)
    expect(doctype).to be_instance_of RelatonIsoBib::DocumentType
    expect(doctype.type).to eq "technical-specification"
  end

  it "returns IWA type" do
    subject.instance_variable_set :@id, "IWA 123:2015"
    doctype = subject.send(:fetch_type)
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

  context do
    before { subject.instance_variable_set :@doc, doc }

    describe "#id" do
      it "returns document ID" do
        expect(subject.id).to eq "ISO 123:2001"
      end

      it "fails to parse document ID" do
        expect(doc).to receive(:at).with("//h1/span[1]").and_return nil
        expect(subject.id).to be_nil
        expect(errors).to eq id: true
      end
    end

    describe "#edition" do
      it "returns edition" do
        expect(subject.edition).to eq "3"
        expect(errors).to eq edition: false
      end

      it "fails to parse edition" do
        expect(doc).to receive(:at).with("//div[div[.='Edition']]/text()[last()]").and_return nil
        expect(subject.edition).to be_nil
        expect(errors).to eq edition: true
      end
    end

    describe "#fetch_relaton_docids" do
      let(:docid) { subject.fetch_relaton_docids }
      let(:pubid) { "ISO 123:2001" }
      let(:isoref) { "ISO 123:2001(E)" }
      let(:urn) { "urn:iso:std:iso:123:stage-90.93" }

      it "returns PubID and URN RelatonBib document identifiers" do
        expect(docid.map(&:id)).to eq([pubid, isoref, urn])
      end
    end

    it("#isoref") { expect(subject.isoref).to eq "ISO 123:2001(E)" }

    it "#fetch_titles_abstract" do
      expect(subject).to receive(:get_page).with("/fr/standard/23281.html").and_return [doc_fr, "url-fr"]
      title, abstract, langs = subject.send(:fetch_titles_abstract)
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title[0].type).to eq "title-intro"
      expect(title[1].type).to eq "title-main"
      expect(abstract[0][:content]).to include "This International Standard specifies procedures"
      expect(langs).to eq [{ lang: "en" }, { lang: "fr", path: "/fr/standard/23281.html" }]
    end

    describe "#parse_abstract" do
      it "returns abstract" do
        abstract = subject.send(:parse_abstract, doc, "en")
        expect(abstract[:content]).to include "This International Standard specifies procedures"
        expect(abstract[:language]).to eq "en"
        expect(abstract[:script]).to eq "Latn"
        expect(abstract[:format]).to eq "text/plain"
        expect(errors).to eq abstract: false
      end

      it "fails to parse abstract" do
        expect(doc).to receive(:xpath).with(
          "//div[@itemprop='description']/p|//div[@itemprop='description']/ul/li",
        ).and_return []
        expect(subject.send(:parse_abstract, doc, "en")).to be_nil
        expect(errors).to eq abstract: true
      end
    end

    describe "#languages" do
      it "returns languages" do
        expect(subject.send(:languages)).to eq [{ lang: "en" }, { lang: "fr", path: "/fr/standard/23281.html" }]
        expect(errors).to eq language: false
      end

      it "fails to parse languages" do
        expect(doc).to receive(:css).with("li#lang-switcher ul li a").and_return []
        expect(subject.send(:languages)).to eq [{ lang: "en" }]
        expect(errors).to eq language: true
      end
    end

    context "#get_page" do
      it "no error" do
        uri = double "uri", to_s: :url
        expect(subject).to receive(:get_redirection).with("/path").and_return [:resp, uri]
        expect(subject).to receive(:try_if_fail).with(:resp, uri).and_return :doc
        expect(subject.send(:get_page, "/path")).to eq %i[doc url]
      end

      it "error" do
        expect(subject).to receive(:get_redirection).with("/path").and_raise(SocketError).exactly(4).times
        expect { subject.send(:get_page, "/path") }.to raise_error RelatonBib::RequestError
      end
    end

    it "#fetch_docnumber" do
      docnumber = subject.send(:fetch_docnumber)
      expect(docnumber).to eq "123"
    end

    it "#fetch_structuredidentifier" do
      si = subject.send(:fetch_structuredidentifier)
      expect(si).to be_instance_of RelatonIsoBib::StructuredIdentifier
      expect(si.project_number).to eq "ISO 123"
      expect(si.part).to be_nil
      expect(si.type).to eq "ISO"
    end

    describe "#item_ref" do
      it "returns item reference" do
        expect(subject.send(:item_ref, doc)).to eq "ISO 123:2001"
        expect(errors).to eq reference: false
      end

      it "fails to parse item reference" do
        expect(doc).to receive(:at).with("//main//section/div/div/div//h1/span[1]").and_return nil
        expect(subject.send(:item_ref, doc)).to be_nil
        expect(errors).to eq reference: true
      end
    end

    it "#fetch_status" do
      status = subject.send(:fetch_status)
      expect(status).to be_instance_of RelatonBib::DocumentStatus
      expect(status.stage.value).to eq "90"
      expect(status.substage.value).to eq "93"
    end

    describe "#stage_code" do
      it "returns stage code" do
        expect(subject.send(:stage_code)).to eq "90.93"
        expect(errors).to eq stage: false
      end

      it "fails to parse stage code" do
        expect(doc).to receive(:at).with(
          "//ul[@class='dropdown-menu']/li[@class='active']/a/span[@class='stage-code']",
        ).and_return nil
        expect(subject.send(:stage_code)).to be_nil
        expect(errors).to eq stage: true
      end
    end

    describe "#fetch_workgroup" do
      it "returns workgroup" do
        wg = subject.send(:fetch_workgroup)
        expect(wg).to be_instance_of RelatonIsoBib::EditorialGroup
        expect(wg.technical_committee).to be_instance_of Array
        expect(wg.technical_committee[0]).to be_instance_of RelatonBib::WorkGroup
        expect(wg.technical_committee[0].name).to eq "Raw materials (including latex) for use in the rubber industry"
        expect(wg.technical_committee[0].identifier).to eq "ISO/TC 45/SC 3"
        expect(wg.technical_committee[0].type).to eq "TC"
        expect(wg.technical_committee[0].number).to eq 45
        expect(errors).to eq workgroup: false
      end

      it "fails to parse workgroup" do
        expect(doc).to receive(:at).with(
          "//div[contains(., 'Technical Committe')]/following-sibling::span/a",
        ).and_return nil
        expect(subject.send(:fetch_workgroup)).to be_nil
        expect(errors).to eq workgroup: true
      end
    end

    describe "#fetch_relations" do
      it "returns relations" do
        relations = subject.send(:fetch_relations)
        expect(relations).to be_instance_of Array
        expect(relations.size).to eq 1
        expect(relations.first[:type]).to eq "obsoletes"
        expect(relations.first[:bibitem]).to be_instance_of RelatonIsoBib::IsoBibliographicItem
        expect(relations.first[:bibitem].formattedref.content).to eq "ISO 123:1985"
        expect(relations.first[:bibitem].docidentifier.first.id).to eq "ISO 123:1985"
        expect(relations.first[:bibitem].docidentifier.first.type).to eq "ISO"
        expect(relations.first[:bibitem].docidentifier.first.primary).to be true
        expect(errors).to eq relation: false
      end

      it "fails to parse relations" do
        expect(doc).to receive(:xpath).with(
          "//ul[@class='steps']/li", "//div[contains(@class, 'sub-step')]"
        ).and_return []
        expect(subject.send(:fetch_relations)).to be_empty
        expect(errors).to eq relation: true
      end
    end

    it "#fetch_contributors" do
      contrib = subject.send(:fetch_contributors)
      expect(contrib).to be_instance_of Array
      expect(contrib.size).to eq 1
      expect(contrib.first[:entity][:abbreviation]).to eq "ISO"
      expect(contrib.first[:entity][:name]).to eq "International Organization for Standardization"
      expect(contrib.first[:entity][:url]).to eq "www.iso.org"
      expect(contrib.first[:role]).to eq [{ type: "publisher" }]
    end

    it "#fetch_ics" do
      ics = subject.send(:fetch_ics)
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
      link = subject.send(:fetch_link, "https://www.iso.org/standard/62510.html")
      expect(link).to be_instance_of Array
      expect(link.size).to eq 4
      expect(link.first[:type]).to eq "src"
      expect(link.first[:content]).to eq "https://www.iso.org/standard/62510.html"
      expect(link[1][:type]).to eq "obp"
      expect(link[1][:content]).to eq "https://www.iso.org/obp/ui/en/#!iso:std:23281:en"
      expect(link[2][:type]).to eq "rss"
      expect(link[2][:content]).to eq "https://www.iso.org/contents/data/standard/02/32/23281.detail.rss"
    end

    context "#relation_type" do
      it "obsoletes" do
        type_date = subject.send(:relation_type, "Previously")
        expect(type_date).to eq ["obsoletes", []]
      end

      it "obsoletes" do
        type_date = subject.send(:relation_type, "Will be replaced by")
        expect(type_date).to eq ["obsoletes", []]
      end

      it "updates" do
        type_date = subject.send :relation_type, "Corrigenda / Amendments"
        expect(type_date).to eq ["updates", [{ on: "2021-06-07", type: "circulated" }]]
      end

      it "updates" do
        type_date = subject.send(:relation_type, "Revised by")
        expect(type_date).to eq ["updates", [{ on: "2021-06-07", type: "circulated" }]]
      end

      it "updates" do
        typed_date = subject.send(:relation_type, "Now confirmed")
        expect(typed_date).to eq ["updates", [{ on: "2021-06-07", type: "circulated" }]]
      end
    end

    context "#fetch_dates" do
      it "published from doc" do
        dates = subject.send(:fetch_dates)
        expect(dates).to be_instance_of Array
        expect(dates.size).to eq 1
        expect(dates.first[:type]).to eq "published"
        expect(dates.first[:on]).to eq "2001-05"
      end

      it "published from doc when ID is undated" do
        dates = subject.send(:fetch_dates)
        expect(dates).to be_instance_of Array
        expect(dates.size).to eq 1
        expect(dates.first[:type]).to eq "published"
        expect(dates.first[:on]).to eq "2001-05"
      end

      it "published & updated from doc" do
        expect(doc).to receive(:at).with("//span[@itemprop='releaseDate']").and_return double(text: "2002-06-07")
        allow(doc).to receive(:at).and_call_original
        dates = subject.send(:fetch_dates)
        expect(dates.size).to eq 2
        expect(dates[0][:type]).to eq "published"
        expect(dates[0][:on]).to eq "2001"
        expect(dates[1][:type]).to eq "updated"
        expect(dates[1][:on]).to eq "2002-06-07"
      end

      it "from reference" do
        expect(doc).to receive(:at).with("//span[@itemprop='releaseDate']").and_return nil
        allow(doc).to receive(:at).and_call_original
        dates = subject.send(:fetch_dates)
        expect(dates.size).to eq 1
        expect(dates[0][:type]).to eq "published"
        expect(dates[0][:on]).to eq "2001"
      end

      it "corrected" do
        expect(doc).to receive(:at).with("//span[@itemprop='releaseDate']").and_call_original
        expect(doc).to receive(:at).with("//span[@itemprop='dateModified']").and_return double(text: "2002-06-07")
        allow(doc).to receive(:at).and_call_original
        dates = subject.send(:fetch_dates)
        expect(dates.size).to eq 2
        expect(dates[1][:type]).to eq "corrected"
        expect(dates[1][:on]).to eq "2002-06-07"
      end
    end

    context "#fetch_copyright" do
      it "get date from ID" do
        expect(subject.send(:fetch_copyright)).to eq [{ from: "2001", owner: [{ name: "ISO" }]}]
      end

      it "parse date from doc" do
        expect(subject).to receive(:item_ref).and_return "ISO 123"
        expect(subject.send(:fetch_copyright)).to eq [{ from: "2001", owner: [{ name: "ISO" }]}]
      end
    end
  end

  context "#get_redirection" do
    before do
      expect(URI).to receive(:parse).with("#{RelatonIso::Scrapper::DOMAIN}/path").and_return :uri
    end
    it "found without redirection" do
      resp = double "response", code: "200"
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
      expect(subject.send(:get_redirection, "/path")).to eq [resp, :uri]
    end

    it "found with redirection" do
      resp = double "response", code: "301"
      expect(resp).to receive(:[]).with("location").and_return "/new_path"
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
      expect(URI).to receive(:parse).with("#{RelatonIso::Scrapper::DOMAIN}/new_path").and_return :uri2
      resp2 = double "response 2", code: "200"
      expect(Net::HTTP).to receive(:get_response).with(:uri2).and_return resp2
      expect(subject.send(:get_redirection, "/path")).to eq [resp2, :uri2]
    end

    it "not found" do
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return(double(code: "504")).exactly(4).times
      expect { subject.send(:get_redirection, "/path") }.to raise_error RelatonBib::RequestError
    end

    context "retry" do
      let(:resp) { double(code: "200") }

      it do
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Errno::EPIPE).twice
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_return(resp)
        expect(subject.send(:get_redirection, "/path")).to eq [resp, :uri]
      end

      it "limit" do
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Errno::EPIPE).exactly(3).times
        expect { subject.send(:get_redirection, "/path") }.to raise_error Errno::EPIPE
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
      doc = subject.send(:try_if_fail, resp, :uri)
      expect(doc.at("h1").text).to eq "ISO 123"
    end

    it "fail" do
      expect(resp).to receive(:body).and_return("<html><body></body></html>").exactly(10).times
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return(resp).exactly(10).times
      expect do
        subject.send(:try_if_fail, resp, :uri)
      end.to raise_error RelatonBib::RequestError
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
      title = subject.send(:fetch_title, doc, "en")
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
      title = subject.send(:fetch_title, doc, "en")
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
      title = subject.send(:fetch_title, doc, "en")
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
      title = subject.send(:fetch_title, doc, "en")
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

  describe "#parse_titles" do
    it "returns title" do
      title = subject.send(:parse_titles, doc)
      expect(title).to eq ["Rubber latex", "Sampling", nil]
      expect(errors).to eq title: false
    end

    it "fails to parse title" do
      expect(doc).to receive(:xpath).with("//h1[@class='stdTitle']/span[position()>1]").and_return []
      expect(subject.send(:parse_titles, doc)).to eq []
      expect(errors).to eq title: true
    end
  end
end
