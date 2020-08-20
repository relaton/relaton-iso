# frozen_string_literal: true

require "relaton_iso/iso_bibliography"

RSpec.describe RelatonIso::IsoBibliography do
  let(:hit_pages) { RelatonIso::IsoBibliography.search("19115") }

  it "raise access error" do
    http = double
    expect(http).to receive(:get).and_raise SocketError
    expect(http).to receive(:use_ssl=).with(true)
    expect(Net::HTTP).to receive(:new).and_return http
    expect { RelatonIso::IsoBibliography.search "19155" }.
      to raise_error RelatonBib::RequestError
  end

  it "fetch hits" do
    VCR.use_cassette "hits" do
      hits = RelatonIso::IsoBibliography.search("ISO 19115")
      expect(hits).to be_instance_of RelatonIso::HitCollection
      expect(hits.first).to be_instance_of RelatonIso::Hit
      expect(hits.first.fetch).to be_instance_of RelatonIsoBib::IsoBibliographicItem
    end
  end

  it "return xml of hit" do
    VCR.use_cassette "hit" do
      hits = RelatonIso::IsoBibliography.search("ISO 19115")
      xml = hits[0].to_xml bibdata: true
      file_path = "spec/support/hit.xml"
      File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
      expect(xml).to be_equivalent_to(
        File.read(file_path, encoding: "utf-8").sub(
          %r{<fetched>[^<]+</fetched>}, "<fetched>#{Date.today}</fetched>"
        ),
      )
    end
  end

  it "return xml of hits collection" do
    VCR.use_cassette "hit_collection_xml" do
      hits = RelatonIso::IsoBibliography.search "ISO 19115"
      xml = hits.to_xml
      file_path = "spec/support/hits.xml"
      File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
      expect(xml).to be_equivalent_to(
        File.read(file_path, encoding: "utf-8").gsub(
          %r{<fetched>[^<]+</fetched>}, "<fetched>#{Date.today}</fetched>"
        ),
      )
    end
  end

  it "return string of hit collection" do
    VCR.use_cassette "hits" do
      hits = RelatonIso::IsoBibliography.search "ISO 19115"
      expect(hits.to_s).to eq(
        "<RelatonIso::HitCollection:#{format('%#.14x', hits.object_id << 1)} "\
        "@ref=ISO 19115 @fetched=false>",
      )
    end
  end

  describe "iso bibliography item" do
    subject do
      VCR.use_cassette "hits" do
        hits = RelatonIso::IsoBibliography.search("ISO 19115")
        hits.first.fetch
      end
    end

    it "return list of titles" do
      expect(subject.title).to be_instance_of Array
    end

    it "return en title" do
      expect(subject.title(lang: "en").first).to be_instance_of RelatonBib::TypedTitleString
    end

    it "return string of abstract" do
      formatted_string = subject.abstract(lang: "en")
      expect(subject.abstract(lang: "en").to_s).to eq formatted_string&.content.to_s
    end

    it "return item urls" do
      url_regex = %r{https:\/\/www\.iso\.org\/standard\/\d+\.html}
      expect(subject.url).to match(url_regex)
      expect(subject.url(:src)).to be_instance_of String
      rss_regex = %r{https:\/\/www\.iso\.org\/contents\/data\/standard\/\d{2}
      \/\d{2}\/\d+\.detail\.rss}x
      expect(subject.url(:rss)).to match(rss_regex)
    end

    it "return dates" do
      expect(subject.date.length).to eq 1
      expect(subject.date.first.type).to eq "published"
      expect(subject.date.first.on).to be_instance_of Date
    end

    # it 'filter dates by type' do
    #   expect(isobib_item.dates.filter(type: 'published').first.from)
    #     .to be_instance_of(Time)
    # end

    it "return document status" do
      expect(subject.status).to be_instance_of RelatonBib::DocumentStatus
    end

    it "return workgroup" do
      expect(subject.editorialgroup).to be_instance_of RelatonIsoBib::EditorialGroup
    end

    # it 'workgroup equal first contributor entity' do
    #   expect(isobib_item.workgroup).to eq isobib_item.contributors.first.entity
    # end

    # it 'return worgroup\'s url' do
    #   expect(isobib_item.workgroup.url).to eq 'www.iso.org'
    # end

    it "return relations" do
      expect(subject.relation).to be_instance_of RelatonBib::DocRelationCollection
    end

    it "return replace realations" do
      expect(subject.relation.replaces.length).to eq 0
    end

    it "return ICS" do
      expect(subject.ics.first.fieldcode).to eq "35"
      expect(subject.ics.first.description).to eq "IT applications in science"
    end
  end

  describe "get" do
    # let(:hit_pages) { RelatonIso::IsoBibliography.search("19115") }

    it "gets a code" do
      VCR.use_cassette "iso_19115_1" do
        results = RelatonIso::IsoBibliography.get("ISO 19115-1", nil, {}).to_xml
        expect(results).to include %(<bibitem id="ISO19115-1" type="standard">)
        expect(results).to include %(<on>2014</on>)
        expect(results.gsub(/<relation.*<\/relation>/m, "")).not_to include %(<on>2014</on>)
        expect(results).to include %(<docidentifier type="ISO">ISO 19115-1:2014</docidentifier>)
        expect(results).not_to include %(<docidentifier type="ISO">ISO 19115</docidentifier>)
      end
    end

    it "gets an all-parts code" do
      VCR.use_cassette "iso_19115_all_parts" do
        results = RelatonIso::IsoBibliography.get("ISO 19115", nil, all_parts: true)
        xml = results.to_xml bibdata: true
        file_path = "spec/support/all_parts.xml"
        File.write file_path, xml, encoding: "UTF-8" unless File.exist? file_path
        expect(xml).to be_equivalent_to(
          File.read(file_path, encoding: "utf-8").gsub(%r{<fetched>[^<]+</fetched>}, "<fetched>#{Date.today}</fetched>"),
        )
        expect(xml).to include %(<project-number>ISO 19115 (all parts)</project-number>)
        expect(xml).to include %(<docidentifier type="ISO">ISO 19115 (all parts)</docidentifier>)
      end
    end

    it "gets a keep-year code" do
      VCR.use_cassette "iso_19115_1_keep_year" do
        results = RelatonIso::IsoBibliography.get("ISO 19115-1", nil, keep_year: true).to_xml
        expect(results).to include %(<bibitem id="ISO19115-1-2014" type="standard">)
        expect(results.gsub(/<relation.*<\/relation>/m, "")).to include %(<on>2014</on>)
        expect(results).to include %(<docidentifier type="ISO">ISO 19115-1:2014</docidentifier>)
      end
    end

    it "gets a code and year successfully" do
      VCR.use_cassette "iso_19115_2003" do
        results = RelatonIso::IsoBibliography.get("ISO 19115", "2003", {})
          .to_xml
        expect(results).to include(
          %(<on>2003</on>)
        )
        expect(results).not_to include(
          %(<docidentifier type="ISO">ISO 19115-1:2003</docidentifier>)
        )
        expect(results).to include(
          %(<docidentifier type="ISO">ISO 19115:2003</docidentifier>)
        )
      end
    end

    it "gets reference with an year in a code" do
      VCR.use_cassette "iso_19115_1_2014" do
        results = RelatonIso::IsoBibliography.get("ISO 19115-1:2014", nil, {})
          .to_xml
        expect(results).to include %(<on>2014</on>)
      end
    end

    it "undated reference gets a newest and active" do
      VCR.use_cassette "iso_123" do
        result = RelatonIso::IsoBibliography.get "ISO 123", nil, keep_year: true
        expect(result.date.first.on.year).to eq 2001
      end
    end

    it "gets a code and year unsuccessfully" do
      VCR.use_cassette "iso_19115_2015" do
        results = RelatonIso::IsoBibliography.get("ISO 19115", "2015", {})
        expect(results).to be nil
      end
    end

    it "warns when a code matches a resource but the year does not" do
      VCR.use_cassette "iso_19115_2015" do
        expect { RelatonIso::IsoBibliography.get("ISO 19115", "2015", {}) }
          .to output(
            /There was no match for 2015, though there were matches found for/
          ).to_stderr
      end
    end

    it "warns when resource with part number not found on ISO website" do
      VCR.use_cassette "iso_19115_30_2014" do
        expect { RelatonIso::IsoBibliography.get("ISO 19115-30", "2014", {}) }
          .to output(
            /The provided document part may not exist, or the document may no /
          ).to_stderr
      end
    end

    it "warns when resource without part number not found on ISO website" do
      VCR.use_cassette "iso_00000_2014" do
        expect { RelatonIso::IsoBibliography.get("ISO 00000", "2014", {}) }
          .to output(
            /If you wanted to cite all document parts for the reference/
          ).to_stderr
      end
    end

    it "search ISO/IEC if search ISO failed" do
      VCR.use_cassette("iso_2382_2015") do
        result = RelatonIso::IsoBibliography.get("ISO 2382", "2015", {})
        expect(result.docidentifier.first.id).to eq "ISO/IEC 2382:2015"
      end
    end

    it "fetch correction" do
      VCR.use_cassette "iso_19110_amd_1_2011" do
        result = RelatonIso::IsoBibliography.get("ISO 19110/Amd 1:2011", "2011")
        expect(result.docidentifier.first.id).to eq "ISO 19110:2005/Amd 1:2011"
      end
    end

    it "fetch PRF Amd" do
      VCR.use_cassette "iso_3839_1996_prf_amd_1" do
        result = RelatonIso::IsoBibliography.get "ISO 3839:1996/PRF Amd 1"
        expect(result.docidentifier.first.id).to eq "ISO 3839:1996/PRF Amd 1"
      end
    end

    it "fetch CD Amd" do
      VCR.use_cassette "iso_16063_1_1999_cd_amd_2" do
        result = RelatonIso::IsoBibliography.get "ISO 16063-1:1998/CD Amd 2"
        expect(result.docidentifier.first.id).to eq "ISO 16063-1:1998/CD Amd 2"
      end
    end

    it "fetch WD Amd" do
      VCR.use_cassette "iso_iec_23008_1_wd_amd_1" do
        result = RelatonIso::IsoBibliography.get "ISO/IEC 23008-1/WD Amd 1", nil, {}
        expect(result.docidentifier.first.id).to eq "ISO/IEC 23008-1/WD Amd 1"
      end
    end

    it "fetch AWI Amd" do
      VCR.use_cassette "iso_10844_2014_awi_amd_1" do
        result = RelatonIso::IsoBibliography.get "ISO 10844:2014/AWI Amd 1", nil, {}
        expect(result.docidentifier.first.id).to eq "ISO 10844:2014/AWI Amd 1"
      end
    end

    it "fetch NP Amd" do
      VCR.use_cassette "iso_1862_1_2017_np_amd_1" do
        result = RelatonIso::IsoBibliography.get "ISO 18562-1:2017/NP Amd 1", nil, {}
        expect(result.docidentifier.first.id).to eq "ISO 18562-1:2017/NP Amd 1"
      end
    end

    it "fetch ISO/IEC/IEEE" do
      VCR.use_cassette "iso_iec_ieee_9945_2009" do
        result = RelatonIso::IsoBibliography.get("ISO/IEC/IEEE 9945:2009")
        expect(result.docidentifier.first.id).to eq "ISO/IEC/IEEE 9945:2009"
        expect(result.contributor[0].entity.name[0].content).to eq(
          "International Organization for Standardization",
        )
        expect(result.contributor[1].entity.name[0].content).to eq(
          "International Electrotechnical Commission",
        )
        expect(result.contributor[2].entity.name[0].content).to eq(
          "Institute of Electrical and Electronics Engineers",
        )
      end
    end

    it "fetch ISO 8000-102" do
      VCR.use_cassette "iso_8000_102" do
        result = RelatonIso::IsoBibliography.get "ISO 8000-102:2009", nil, {}
        expect(result.docidentifier.first.id).to eq "ISO 8000-102:2009"
      end
    end

    it "fetch public guide" do
      VCR.use_cassette "iso_guide_82_2014" do
        result = RelatonIso::IsoBibliography.get "ISO Guide 82:2014", nil, {}
        expect(result.link.detect { |l| l.type == "pub" }.content.to_s).to include "http://isotc.iso.org/livelink/livelink"
      end
    end

    it "fetch undefined stadard" do
      VCR.use_cassette "not_found" do
        result = RelatonIso::IsoBibliography.get "ISO ABCDEFGH", nil, {}
        expect(result).to be_nil
      end
    end

    it "fetch circulated date" do
      VCR.use_cassette "iso_iec_8824_1_2015" do
        bib = RelatonIso::IsoBibliography.get("ISO/IEC 8824-1:2015")
        expect(bib.relation[3].bibitem.date.first.on.to_s).to eq "2015-11-12"
      end
    end

    context "try to fetch stages" do
      it "ISO" do
        VCR.use_cassette "iso_20360" do
          result = RelatonIso::IsoBibliography.get "ISO 20360", nil, {}
          expect(result.docidentifier.first.id).to eq "ISO/DIS 20360"
        end
      end

      it "ISO/IEC" do
        VCR.use_cassette "iso_iec_29110_5_1_3_2017" do
          result = RelatonIso::IsoBibliography.get "ISO/IEC 29110-5-1-3:2017", nil, {}
          expect(result.docidentifier.first.id).to eq "ISO/IEC TR 29110-5-1-3:2017"
        end
      end

      it "fetch ISO 4" do
        VCR.use_cassette "iso_4" do
          result = RelatonIso::IsoBibliography.get "ISO 4"
          expect(result.docidentifier.first.id).to eq "ISO 4 (all parts)"
        end
      end
    end

    context "fetch specific language" do
      it "en" do
        VCR.use_cassette "iso_19115_en" do
          result = RelatonIso::IsoBibliography.get("ISO 19115", nil, lang: "en").to_xml
          file = "spec/support/iso_19115_en.xml"
          File.write file, result, encoding: "UTF-8" unless File.exist? file
          expect(result).to be_equivalent_to File.read(file, encoding: "UTF-8").
            gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        end
      end

      it "fr" do
        VCR.use_cassette "iso_19115_fr" do
          result = RelatonIso::IsoBibliography.get("ISO 19115", nil, lang: "fr").to_xml
          file = "spec/support/iso_19115_fr.xml"
          File.write file, result, encoding: "UTF-8" unless File.exist? file
          expect(result).to be_equivalent_to File.read(file, encoding: "UTF-8").
            gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        end
      end
    end

    it "return not found" do
      VCR.use_cassette "iso_7372_directory" do
        result = RelatonIso::IsoBibliography.get "ISO 7372 Directory", nil, {}
        expect(result).to be_nil
      end
    end
  end
end
