# frozen_string_literal: true

# require "relaton_iso/iso_bibliography"

RSpec.describe Relaton::Iso::Bibliography do
  it "raise access error" do
    hc = double "hit_collection"
    expect(Relaton::Iso::HitCollection).to receive(:new).and_return hc
    expect(hc).to receive(:find).and_raise SocketError
    expect { described_class.search "ISO 19115" }.to raise_error Relaton::RequestError
  end

  it "fetch hits" do
    VCR.use_cassette "hits" do
      hits = described_class.search("ISO 19115")
      expect(hits).to be_instance_of Relaton::Iso::HitCollection
      expect(hits.first).to be_instance_of Relaton::Iso::Hit
      expect(hits.first.item).to be_instance_of(Relaton::Iso::ItemData)
    end
  end

  it "return xml of hit" do
    VCR.use_cassette "hit" do
      hits = described_class.search("ISO 19115-2:2019")
      xml = hits[0].item.to_xml bibdata: true
      file_path = "spec/fixtures/hit.xml"
      File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
      expect(xml).to be_equivalent_to File.read(file_path, encoding: "utf-8")
        .sub %r{<fetched>[^<]+</fetched>}, "<fetched>#{Date.today}</fetched>"
    end
  end

  it "return string of hit collection" do
    VCR.use_cassette "hits" do
      hits = described_class.search "ISO 19115"
      objid = format("%<id>#.14x", id: hits.object_id << 1)
      expect(hits.to_s).to eq(
        "<Relaton::Iso::HitCollection:#{objid} @ref=ISO 19115 @fetched=false>",
      )
    end
  end

  describe "iso bibliography item" do
    subject do
      VCR.use_cassette "iso_19115_2003" do
        described_class.get("ISO 19115:2003")
      end
    end

    it "return list of titles" do
      expect(subject.title).to be_instance_of(Array)
      expect(subject.title.first).to be_instance_of Relaton::Bib::Title
    end

    it "return en title" do
      expect(subject.title(:en).first).to be_instance_of Relaton::Bib::Title
    end

    it "return string of abstract" do
      expect(subject.abstract(:en).first.content).to include "ISO 19115:2003 defines the schema"
    end

    it "return item urls" do
      url_regex = %r{https://www\.iso\.org/standard/\d+\.html}
      expect(subject.source.first.content).to match(url_regex)
      expect(subject.source(:src)).to be_instance_of String
      rss_regex = %r{https://www\.iso\.org/contents/data/standard/\d{2}
      /\d{2}/\d+\.detail\.rss}x
      expect(subject.source(:rss)).to match(rss_regex)
    end

    it "return dates" do
      expect(subject.date.length).to eq 1
      expect(subject.date.first.type).to eq "published"
      expect(subject.date.first.at).to be_instance_of Relaton::Bib::StringDate::Value
    end

    it "return document status" do
      expect(subject.status).to be_instance_of Relaton::Bib::Status
    end

    it "return ext without editorialgroup" do
      expect(subject.ext).to be_instance_of Relaton::Iso::Ext
      expect(subject.ext.doctype.content).to eq "international-standard"
      expect(subject.ext).not_to respond_to(:editorialgroup)
    end

    it "return relations" do
      expect(subject.relation).to be_instance_of Array
      expect(subject.relation.first).to be_instance_of Relaton::Iso::Relation
    end

    it "return replace realations" do
      expect(subject.relation(:replaces).length).to eq 0
    end

    it "return ICS" do
      expect(subject.ext.ics.first.code).to eq "35.240.70"
      expect(subject.ext.ics.first.text).to eq "IT applications in science"
    end
  end

  describe "#get" do
    let(:pubid) { "ISO 19115-1" }
    let(:isoref) { "ISO 19115-1(E)" }
    let(:urn) { "urn:iso:std:iso:19115:-1:stage-90.92" }

    context "gets a code", vcr: { cassette_name: "iso_19115_1" } do
      subject { described_class.get(pubid, nil, {}) }
      let(:xml) { subject.to_xml }

      it "generates correct output" do
        file = "spec/fixtures/iso_19115_keep_year.xml"
        File.write file, xml, encoding: "UTF-8" unless File.exist? file
        expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}(?=<)/, Date.today.to_s)
      end

      it "returns correct document identifiers" do
        expect(subject.docidentifier.map(&:to_s)).to eq([pubid, isoref, urn])
      end
    end

    context "gets all parts document", vcr: { cassette_name: "iso_19115_all_parts" } do
      let(:xml) { subject.to_xml bibdata: true }
      let(:pubid_all_parts) { "ISO 19115 (all parts)" }
      let(:isoref_all_parts) { "ISO 19115(E) (all parts)" }
      let(:urn_all_parts) { "urn:iso:std:iso:19115:ser" }

      shared_examples "all_parts" do
        it "returns (all parts) as identifier part" do
          expect(subject.ext.structuredidentifier.project_number.part).to be_nil
          expect(subject.docidentifier.map(&:to_s)).to eq([pubid_all_parts, isoref_all_parts, urn_all_parts])
        end

        it "include all matched documents without part" do
          expect(subject.relation.map { |r| r.bibitem.formattedref })
            .to include("ISO 19115-1:2014/Amd 1:2018", "ISO 19115-2:2019", "ISO 19115-2:2009")
        end
      end

      context "when using all_parts parameter" do
        subject do
          described_class.get(pubid, nil, all_parts: true)
        end

        it "generates correct xml data" do
          file = "spec/fixtures/all_parts.xml"
          File.write file, xml, encoding: "UTF-8" unless File.exist? file
          expect(xml).to be_equivalent_to File.read(file, encoding: "utf-8")
            .gsub(%r{(?<=<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
        end

        it_behaves_like "all_parts"
      end

      context "when using reference" do
        subject { described_class.get pubid_all_parts }

        it_behaves_like "all_parts"
      end
    end

    context "gets the most recent reference" do
      it "by default" do
        VCR.use_cassette "iso_19115_1_keep_year" do
          file = "spec/fixtures/iso_19115_keep_year.xml"
          xml = described_class.get("ISO 19115-1").to_xml
          File.write file, xml, encoding: "UTF-8" unless File.exist? file
          expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
            .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}(?=<)/, Date.today.to_s)
        end
      end

      it "explicitily" do
        VCR.use_cassette "iso_19115_1_keep_year" do
          file = "spec/fixtures/iso_19115_keep_year.xml"
          xml = described_class.get(
            "ISO 19115-1:2014", nil, keep_year: false
          ).to_xml
          File.write file, xml, encoding: "UTF-8" unless File.exist? file
          expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
            .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}(?=<)/, Date.today.to_s)
        end
      end
    end

    context "gets a code and year successfully" do
      it "with a year as an arg", vcr: "iso_19115_2003" do
        bib = described_class.get("ISO 19115", "2003", {})
        expect(bib.docidentifier[0].to_s).to eq "ISO 19115:2003"
      end

      it "with a year in a code", vcr: "iso_19115_1_2014" do
        bib = described_class.get("ISO 19115-1:2014", nil, {})
        expect(bib.docidentifier[0].to_s).to eq "ISO 19115-1:2014"
      end
    end

    it "undated reference gets a newest and active" do
      VCR.use_cassette "iso_123" do
        result = described_class.get "ISO 123", nil, keep_year: true
        expect(result.date.first.at.to_date.year).to eq 2001
      end
    end

    it "gets a code and year unsuccessfully" do
      VCR.use_cassette "iso_19115_2015" do
        results = described_class.get("ISO 19115", "2015", {})
        expect(results).to be nil
      end
    end

    context "warns when a code matches a resource but the year does not" do
      it "ISO 19115:2015", vcr: "iso_19115_2015" do
        expect { described_class.get("ISO 19115", "2015", {}) }
          .to output(
            /TIP: No match for edition year 2015, but matches exist for `ISO 19115:2003`/,
          ).to_stderr_from_any_process
      end
    end

    context "look up the version with no doctype" do
      it "ISO/TS 19103:2015", vcr: "iso_ts_19103_2015" do
        expect do
          expect(described_class.get("ISO/TS 19103:2015")).to be_nil
        end.to output(/TIP: Matches exist for `ISO 19103:2015`/).to_stderr_from_any_process
      end
    end

    it "warns when resource with part number not found on ISO website" do
      VCR.use_cassette "iso_19115_30_2014" do
        expect { described_class.get("ISO 19115-30", "2014", {}) }
          .to output(
            /TIP: If it cannot be found, the document may no longer be published in parts/,
          ).to_stderr_from_any_process
      end
    end

    it "warns when resource without part number not found on ISO website" do
      VCR.use_cassette "iso_00000_2014" do
        expect { described_class.get("ISO 00000", "2014", {}) }
          .to output(
            /If you wish to cite all document parts for the reference/,
          ).to_stderr_from_any_process
      end
    end

    it "search ISO/IEC if search ISO failed" do
      VCR.use_cassette("iso_iec_2382_2015") do
        result = described_class.get("ISO/IEC 2382", "2015", {})
        expect(result.docidentifier.first.content).to eq "ISO/IEC 2382:2015"
      end
    end

    it "fetch correction" do
      VCR.use_cassette "iso_19110_amd_1_2011" do
        result = described_class.get("ISO 19110:2005/Amd 1:2011", "2005")
        expect(result.docidentifier.first.content).to eq "ISO 19110:2005/Amd 1:2011"
      end
    end

    # it "fetch PRF Amd" do
    #   VCR.use_cassette "iso_prf_amd_1" do
    #     result = described_class.get "ISO 7029:2017/PRF Amd 1"
    #     expect(result.docidentifier.first.content).to eq "ISO 7029:2017/Amd 1"
    #   end
    # end

    it "fetch CD Amd" do
      VCR.use_cassette "iso_16063_1_1999_cd_amd_2" do
        result = described_class.get "ISO 16063-1:1998/CD Amd 2"
        expect(result.docidentifier.first.content).to eq "ISO 16063-1:1998/CD Amd 2"
      end
    end

    it "fetch WD Amd" do
      VCR.use_cassette "iso_iec_23008_1_wd_amd_1" do
        result = described_class.get "ISO/IEC 23008-1/WD Amd 1"
        expect(result.docidentifier.first.to_s).to eq "ISO/IEC 23008-1/WD Amd 1"
        expect(result.relation[0].bibitem.docidentifier[0].content).to eq "ISO/IEC 23008-1:2023/WD Amd 1"
      end
    end

    it "fetch AWI Amd" do
      VCR.use_cassette "iso_avi_amd" do
        result = described_class.get "ISO 10791-6:2014/AWI Amd 1"
        expect(result.docidentifier.first.content).to eq "ISO 10791-6:2014/AWI Amd 1"
      end
    end

    # it "fetch NP Amd" do
    #   VCR.use_cassette "iso_1862_1_2017_np_amd_1" do
    #     result = described_class.get "ISO 18562-1:2017/NP Amd 1"
    #     expect(result.docidentifier.first.content).to eq "ISO 18562-1:2017/NP Amd 1"
    #   end
    # end

    it "fetch ISO/IEC/IEEE" do
      VCR.use_cassette "iso_iec_ieee_9945_2009" do
        result = described_class.get("ISO/IEC/IEEE 9945:2009")
        expect(result.docidentifier.first.content).to eq "ISO/IEC/IEEE 9945:2009"
        expect(result.contributor[0].organization.name[0].content).to eq(
          "International Organization for Standardization",
        )
        expect(result.contributor[1].organization.name[0].content).to eq(
          "International Electrotechnical Commission",
        )
        expect(result.contributor[2].organization.name[0].content).to eq(
          "Institute of Electrical and Electronics Engineers",
        )
      end
    end

    it "fetch ISO 8000-102" do
      VCR.use_cassette "iso_8000_102" do
        result = described_class.get "ISO 8000-102:2009", nil, {}
        expect(result.docidentifier.first.content).to eq "ISO 8000-102:2009"
      end
    end

    it "fetch ISO 125:2020" do
      VCR.use_cassette "iso_125_2020" do
        result = described_class.get "ISO 125:2020", nil, {}
        expect(result.docidentifier.first.content).to eq "ISO 125:2020"
      end
    end

    it "fetch public guide" do
      VCR.use_cassette "iso_guide_82_2019" do
        result = described_class.get "ISO Guide 82:2019", nil, {}
        expect(result.source.detect { |l| l.type == "pub" }.content.to_s)
          .to include("https://isotc.iso.org/livelink/livelink")
      end
    end

    it "fetch circulated date" do
      VCR.use_cassette "iso_iec_8824_1_2015" do
        bib = described_class.get("ISO/IEC 8824-1:2015")
        expect(bib.relation[4].bibitem.date.first.at.to_s).to eq "2021-06-30"
      end
    end

    it "fetch ISO TC 184/SC 4" do
      VCR.use_cassette "iso_tc_184_sc_4" do
        result = described_class.get "ISO TC 184/SC 4 N1110"
        expect(result.docidentifier[0].content).to eq "ISO/TC 184/SC 4 N1110"
        expect(result.docidentifier[0].primary).to be true
      end
    end

    it "fetch ISO 19105:2022" do
      VCR.use_cassette "iso_19105_2022" do
        result = described_class.get "ISO 19105:2022"
        expect(result.docidentifier[0].content).to eq "ISO 19105:2022"
      end
    end

    context "fetch ISO IEC DIR" do
      it "ISO/IEC DIR 1", vcr: "iso_iec_dir_1" do
        result = described_class.get "ISO/IEC DIR 1"
        expect(result.docidentifier[0].to_s).to eq "ISO/IEC DIR 1"
      end

      it "ISO/IEC DIR 2 ISO", vcr: "iso_iec_dir_2_iso" do
        result = described_class.get "ISO/IEC DIR 2 ISO"
        expect(result.docidentifier[0].to_s).to eq "ISO/IEC DIR 2 ISO"
      end
    end

    it "fetch ISO 19156" do
      VCR.use_cassette "iso_19156" do
        result = described_class.get "ISO 19156"
        expect(result.docidentifier[0].to_s).to eq "ISO 19156"
      end
    end

    it "fetch ISO 6709:2008/Cor 1:2009" do
      VCR.use_cassette "iso_6709_2008_cor_1_2009" do
        result = described_class.get "ISO 6709:2008/Cor 1:2009"
        expect(result.docidentifier[0].to_s).to eq "ISO 6709:2008/Cor 1:2009"
      end
    end

    it "fetch ISO/IEC 10646", vcr: "iso_iec_10646" do
      result = described_class.get "ISO/IEC 10646"
      expect(result.docidentifier[0].to_s).to eq "ISO/IEC 10646"
    end

    it "ISO/IEC Guide 2:1991", vcr: "iso_iec_guide_2_1991" do
      result = described_class.get "ISO/IEC Guide 2:1991"
      expect(result.docidentifier[0].to_s).to eq "ISO/IEC Guide 2:1991"
    end

    it "ISO/IEC 27001:2022", vcr: "iso_iec_27001_2022" do
      result = described_class.get "ISO/IEC 27001:2022"
      expect(result.docidentifier[0].to_s).to eq "ISO/IEC 27001:2022"
    end

    it "doc with corrected date", vcr: "iso_iec_2382_2015" do
      result = described_class.get "ISO/IEC 2382:2015"
      expect(result.docidentifier[0].to_s).to eq "ISO/IEC 2382:2015"
      corrected_date = result.date.detect { |d| d.type == "corrected" }
      expect(corrected_date.at.to_s).to eq "2022-10"
    end

    context "try to fetch stages" do
      it "ISO" do
        VCR.use_cassette "iso_22934" do
          result = described_class.get "ISO 22934", nil, {}
          expect(result.docidentifier.first.to_s).to eq "ISO 22934"
        end
      end

      it "ISO/IEC" do
        VCR.use_cassette "iso_iec_tr_29110_5_1_3_2017" do
          result = described_class.get "ISO/IEC TR 29110-5-1-3:2017"
          expect(result.docidentifier.first.to_s).to eq "ISO/IEC TR 29110-5-1-3:2017"
        end
      end

      it "fetch ISO 4" do
        VCR.use_cassette "iso_4" do
          result = described_class.get "ISO 4"
          expect(result.docidentifier.first.to_s).to eq "ISO 4"
        end
      end
    end

    # context "fetch specific language" do
    #   it "en" do
    #     VCR.use_cassette "iso_19115_en" do
    #       result = described_class.get("ISO 19115", nil, lang: "en")
    #       xml = result.to_xml
    #       file = "spec/fixtures/iso_19115_en.xml"
    #       File.write file, xml, encoding: "UTF-8" unless File.exist? file
    #       expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
    #         .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    #     end
    #   end

    #   it "fr" do
    #     VCR.use_cassette "iso_19115_fr" do
    #       result = described_class.get("ISO 19115", nil, lang: "fr")
    #         .to_xml
    #       file = "spec/fixtures/iso_19115_fr.xml"
    #       File.write file, result, encoding: "UTF-8" unless File.exist? file
    #       expect(result).to be_equivalent_to File.read(file, encoding: "UTF-8")
    #         .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    #     end
    #   end
    # end

    context "return not found" do
      it do
        VCR.use_cassette "not_found" do
          result = described_class.get "ISO 111111"
          expect(result).to be_nil
        end
      end

      it do
        VCR.use_cassette "git_hub_not_found" do
          result = described_class.get "ISO TC 184/SC 4 N111"
          expect(result).to be_nil
        end
      end
    end
  end

  context "publication date filtering" do
    # ISO 19115:2003 has published date "2003-05" (i.e. 2003-05-01)
    it "publication_date_before returns edition before given date", vcr: "iso_19115_2003" do
      result = described_class.get("ISO 19115", "2003",
                                   publication_date_before: Date.new(2004, 1, 1))
      expect(result).not_to be_nil
      expect(result.docidentifier.first.content).to eq "ISO 19115:2003"
    end

    it "publication_date_after returns edition on or after given date", vcr: "iso_19115_2003" do
      result = described_class.get("ISO 19115", "2003",
                                   publication_date_after: Date.new(2003, 1, 1))
      expect(result).not_to be_nil
      expect(result.docidentifier.first.content).to eq "ISO 19115:2003"
    end

    it "combined date filters return edition within range", vcr: "iso_19115_2003" do
      result = described_class.get("ISO 19115", "2003",
                                   publication_date_after: Date.new(2003, 1, 1),
                                   publication_date_before: Date.new(2004, 1, 1))
      expect(result).not_to be_nil
      expect(result.docidentifier.first.content).to eq "ISO 19115:2003"
    end

    it "returns nil when year matches but exact date fails filter", vcr: "iso_19115_2003" do
      # ISO 19115:2003 published 2003-05, filtering after 2003-06 should fail
      result = described_class.get("ISO 19115", "2003",
                                   publication_date_after: Date.new(2003, 6, 1))
      expect(result).to be_nil
    end

    it "returns nil when no editions match the filter", vcr: "iso_19115_2003" do
      result = described_class.get("ISO 19115", "2003",
                                   publication_date_before: Date.new(2002, 1, 1))
      expect(result).to be_nil
    end

    it "filters out relations published after the cut-off date", vcr: "iso_19115_2003" do
      result = described_class.get("ISO 19115", "2003",
                                   publication_date_before: Date.new(2010, 1, 1))
      expect(result).not_to be_nil
      rel_docids = result.relation.map { |r| r.bibitem.docidentifier&.find(&:primary)&.content.to_s }
      # ISO 19115-1:2014 has circulated date 2014-03-19, should be filtered out
      expect(rel_docids).not_to include("ISO 19115-1:2014")
      # ISO 19115:2003/Cor 1:2006 has circulated date 2014-03-19, also filtered out
      expect(rel_docids).not_to include("ISO 19115:2003/Cor 1:2006")
    end

    it "keeps relations published before the cut-off date", vcr: "iso_19115_2003" do
      result = described_class.get("ISO 19115", "2003",
                                   publication_date_before: Date.new(2020, 1, 1))
      expect(result).not_to be_nil
      rel_docids = result.relation.map { |r| r.bibitem.docidentifier&.find(&:primary)&.content.to_s }
      # Both relations have circulated date 2014-03-19, which is before 2020
      expect(rel_docids).to include("ISO 19115-1:2014")
    end

    it "filters out corrected date after the cut-off", vcr: "iso_iec_2382_2015" do
      result = described_class.get("ISO/IEC 2382", "2015",
                                   publication_date_before: Date.new(2020, 1, 1))
      expect(result).not_to be_nil
      # published date (2015-05) should be kept
      pub_date = result.date.find { |d| d.type == "published" }
      expect(pub_date).not_to be_nil
      # corrected date (2022-10) should be filtered out
      corrected_date = result.date.find { |d| d.type == "corrected" }
      expect(corrected_date).to be_nil
    end

    it "skips to_most_recent_reference when date filter is present", vcr: "iso_19115_2003" do
      result = described_class.get("ISO 19115", "2003",
                                   publication_date_before: Date.new(2004, 1, 1))
      expect(result).not_to be_nil
      # Should retain year since date filter skips to_most_recent_reference
      expect(result.docidentifier.first.content).to eq "ISO 19115:2003"
    end
  end

  describe "#isobib_results_filter" do
    context "when data's years matches" do
      it "returns first hit", vcr: "iso_19115_2003" do
        query_pubid = Pubid::Iso::Identifier.parse("ISO 19115:2003")
        hits, missed_year_ids = described_class.send(:isobib_search_filter, query_pubid, {})
        expect(hits).not_to be_empty
        expect(missed_year_ids).to be_empty
      end
    end

    context "when data's years is not matched" do
      it "returns missed years", vcr: "iso_19115_2015" do
        query_pubid = Pubid::Iso::Identifier.parse("ISO 19115:2015")
        _hits, missed_year_ids = described_class.send(:isobib_search_filter, query_pubid, {})
        expect(missed_year_ids).not_to be_empty
      end
    end

    context "when all parts true" do
      "returns hits.to_all_parts"
    end
  end

  describe "#matches_parts?" do
    subject do
      described_class.matches_parts?(
        Pubid::Iso::Identifier.parse(query_pubid), Pubid::Iso::Identifier.parse(pubid),
        all_parts: all_parts
      )
    end

    let(:query_pubid) { "ISO 1234-5" }
    let(:pubid) { "ISO 1234-6" }

    context "when all_parts: true" do
      let(:all_parts) { true }

      it "matches with identifier with different part" do
        expect(subject).to be_truthy
      end

      context "when matching identifier don't have a part" do
        let(:pubid) { "ISO 1234" }

        it "don't match" do
          expect(subject).to be_falsey
        end
      end
    end

    context "when all_parts: false" do
      let(:all_parts) { false }

      it "don't match with idenfifier with different part" do
        expect(subject).to be_falsey
      end
    end
  end

  describe "#matches_base?" do
    subject do
      described_class.matches_base?(Pubid::Iso::Identifier.parse(query_pubid),
                                    Pubid::Iso::Identifier.parse(pubid),
                                    any_types_stages: any_types_stages)
    end

    let(:any_types_stages) { false }

    context "when have equal publisher and number but different parts" do
      let(:query_pubid) { "ISO 6709-1" }
      let(:pubid) { "ISO 6709-2" }

      it { is_expected.to be true }
    end

    context "when have different number" do
      let(:query_pubid) { "ISO 6708" }
      let(:pubid) { "ISO 6709" }

      it { is_expected.to be false }
    end

    context "when have different publisher" do
      let(:query_pubid) { "ISO 6709" }
      let(:pubid) { "IEC 6709" }

      it { is_expected.to be false }
    end

    context "when have different copublisher" do
      let(:query_pubid) { "ISO/IEC 6709" }
      let(:pubid) { "ISO 6709" }

      it { is_expected.to be false }
    end

    context "when have different type" do
      let(:query_pubid) { "ISO/TS 6709" }
      let(:pubid) { "ISO 6709" }

      it { is_expected.to be false }
    end

    context "when have different stage" do
      let(:query_pubid) { "ISO/DIS 6709" }
      let(:pubid) { "ISO 6709" }

      it { is_expected.to be false }
    end

    context "when requested to match with any types and stages" do
      let(:any_types_stages) { true }

      context "when have different stage" do
        let(:query_pubid) { "ISO 6709" }
        let(:pubid) { "ISO/DIS 6709" }

        it { is_expected.to be true }
      end

      context "when have different type" do
        let(:query_pubid) { "ISO 6709" }
        let(:pubid) { "ISO TR 6709" }

        it { is_expected.to be true }
      end

      context "when query already have stage" do
        let(:query_pubid) { "ISO/DIS 6709" }
        let(:pubid) { "ISO 6709" }

        it "do not matches with different stage" do
          expect(subject).to be true
        end
      end

      context "when query already have type" do
        let(:query_pubid) { "ISO TR 6709" }
        let(:pubid) { "ISO 6709" }

        it "do not matches with different type" do
          expect(subject).to be true
        end
      end
    end
  end

  describe "#filter_hits_by_year", vcr: { cassette_name: "iso_19115_2015" } do
    subject { described_class.filter_hits_by_year(hits_collection, year) }
    let(:pubid) { Pubid::Iso::Identifier.parse("ISO 19115") }
    let(:hits_collection) { Relaton::Iso::HitCollection.new(pubid).find }

    context "when year is missing" do
      let(:year) { "2015" }

      it "returns nothing" do
        expect(subject[0]).to be_empty
        expect(subject[1]).not_to be_empty
      end
    end

    context "when year is found" do
      # hits collection contains another years
      let(:year) { "2003" }
      let(:pubid) { Pubid::Iso::Identifier.parse("ISO 19115:2003") }

      it "returns found document" do
        expect(subject[0].first.pubid.to_s).to eq(pubid.to_s)
      end

      it "don't output warning" do
        expect { subject }.not_to output.to_stderr_from_any_process
      end
    end

    it "set pubid year if it is missing" do
      hit = double("hit", pubid: Pubid::Iso::Identifier.parse("ISO 19115"),
                          hit: { year: "2019" })
      result = described_class.filter_hits_by_year([hit], "2019")
      expect(result[0].first.pubid.year).to eq "2019"
    end
  end
  #
  # Do not return missed years if any year matched

  it "rescue from pubid parse error" do
    expect do
      expect(described_class.get("ISO/TC 211 Good Practices")).to be_nil
    end.to output(
      %r{\[relaton-iso\] WARN: \(ISO/TC 211 Good Practices\) Is not recognized as a standards identifier},
    ).to_stderr_from_any_process
  end
end
