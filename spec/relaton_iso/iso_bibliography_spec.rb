# frozen_string_literal: true

require "relaton_iso/iso_bibliography"

RSpec.describe RelatonIso::IsoBibliography do
  let(:hit_pages) { RelatonIso::IsoBibliography.search("19115") }

  it "raise access error" do
    algolia = double
    expect(algolia).to receive(:search).and_raise Algolia::AlgoliaProtocolError.new("404", "Not found")
    expect(Algolia::Index).to receive(:new).and_return algolia
    expect { RelatonIso::IsoBibliography.search "19155" }.
      to raise_error RelatonBib::RequestError
  end

  it "return HitPages instance" do
    mock_algolia 2
    hit_pages = RelatonIso::IsoBibliography.search("19155")
    expect(hit_pages).to be_instance_of RelatonIso::HitPages
    expect(hit_pages.first).to be_instance_of RelatonIso::HitCollection
    expect(hit_pages[1]).to be_instance_of RelatonIso::HitCollection
  end

  it "fetch hits of page" do
    mock_algolia 1
    mock_http_net 10

    hit_pages = RelatonIso::IsoBibliography.search("19115")
    expect(hit_pages.first.fetched).to be_falsy
    expect(hit_pages[0].fetch).to be_instance_of RelatonIso::HitCollection
    expect(hit_pages.first.fetched).to be_truthy
    expect(hit_pages[0].first).to be_instance_of RelatonIso::Hit
  end

  # context "search and fetch" do
  #   it "success" do
  #     mock_algolia 2
  #     mock_http_net 20
  #     results = RelatonIso::IsoBibliography.search_and_fetch("19115")
  #     expect(results.size).to be 10
  #   end

  #   it "raise access error" do

  #   end
  # end

  it "return string of hit" do
    mock_algolia 1
    hit_pages = RelatonIso::IsoBibliography.search("19115")
    expect(hit_pages.first[0].to_s).to eq "<RelatonIso::Hit:"\
      "#{format('%#.14x', hit_pages.first[0].object_id << 1)} "\
      '@text="19115" @fullIdentifier="" @matchedWords=["19115"] '\
      '@category="standard" @title="ISO 19115-1:2014/Amd 1:2018 ">'
  end

  it "return xml of hit" do
    mock_algolia 1
    mock_http_net 2
    hit_pages = RelatonIso::IsoBibliography.search("19115")
    xml = hit_pages.first[2].to_xml bibdata: true
    file_path = "spec/support/hit.xml"
    File.write file_path, xml unless File.exist? file_path
    expect(xml).to be_equivalent_to(
      File.read(file_path).sub(%r{<fetched>[^<]+</fetched>}, "<fetched>#{Date.today}</fetched>"),
    )
  end

  it "return xml of pages" do
    mock_algolia 2
    mock_http_net 20
    hit_pages = RelatonIso::IsoBibliography.search "19115"
    xml = hit_pages.to_xml
    file_path = "spec/support/hit_pages.xml"
    File.write file_path, xml unless File.exist? file_path
    expect(xml).to be_equivalent_to(
      File.read(file_path).gsub(%r{<fetched>[^<]+</fetched>}, "<fetched>#{Date.today}</fetched>"),
    )
  end

  it "return last page of hits" do
    mock_algolia 2
    expect(hit_pages.last).to be_instance_of RelatonIso::HitCollection
  end

  it "iteration pages of hits" do
    mock_algolia 2
    expect(hit_pages.size).to eq 2
    pages = hit_pages.map { |p| p }
    expect(pages.size).to eq 2
    hit_pages.each { |p| expect(p).to be_instance_of RelatonIso::HitCollection }
  end

  it "return string of hit pages" do
    mock_algolia 1
    expect(hit_pages.to_s).to eq(
      "<RelatonIso::HitPages:#{format('%#.14x', hit_pages.object_id << 1)} "\
      "@text=19115 @pages=2>",
    )
  end

  it "return string of hit collection" do
    mock_algolia 1
    expect(hit_pages.first.to_s).to eq(
      "<RelatonIso::HitCollection:#{format('%#.14x', hit_pages.first.object_id << 1)} "\
      "@fetched=false>",
    )
  end

  describe "iso bibliography item" do
    let(:isobib_item) do
      mock_algolia 1
      mock_http_net 2
      hit_pages = RelatonIso::IsoBibliography.search("19155")
      hit_pages.first.first.fetch
    end

    it "return list of titles" do
      expect(isobib_item.title).to be_instance_of Array
    end

    it "return en title" do
      expect(isobib_item.title(lang: "en").first).to be_instance_of RelatonIsoBib::TypedTitleString
    end

    # it "return string of title" do
    #   title = isobib_item.title(lang: "en").first
    #   title_str = title.title_main
    #   title_str = "#{title.title_intro} -- #{title_str}" if title.title_intro && !title.title_intro.empty?
    #   title_str = "#{title_str} -- #{title.title_part}" if title.title_part && !title.title_part.empty?
    #   expect(isobib_item.title(lang: "en").to_s).to eq title_str
    # end

    it "return string of abstract" do
      formatted_string = isobib_item.abstract(lang: "en")
      expect(isobib_item.abstract(lang: "en").to_s).to eq formatted_string&.content.to_s
    end

    it "return item urls" do
      url_regex = %r{https:\/\/www\.iso\.org\/standard\/\d+\.html}
      expect(isobib_item.url).to match(url_regex)
      expect(isobib_item.url(:obp)).to be_instance_of String
      rss_regex = %r{https:\/\/www\.iso\.org\/contents\/data\/standard\/\d{2}
      \/\d{2}\/\d+\.detail\.rss}x
      expect(isobib_item.url(:rss)).to match(rss_regex)
    end

    it "return dates" do
      expect(isobib_item.dates.length).to eq 1
      expect(isobib_item.dates.first.type).to eq "published"
      expect(isobib_item.dates.first.on).to be_instance_of Time
    end

    # it 'filter dates by type' do
    #   expect(isobib_item.dates.filter(type: 'published').first.from)
    #     .to be_instance_of(Time)
    # end

    it "return document status" do
      expect(isobib_item.status).to be_instance_of RelatonBib::DocumentStatus
    end

    it "return workgroup" do
      expect(isobib_item.editorialgroup).to be_instance_of RelatonIsoBib::EditorialGroup
    end

    # it 'workgroup equal first contributor entity' do
    #   expect(isobib_item.workgroup).to eq isobib_item.contributors.first.entity
    # end

    # it 'return worgroup\'s url' do
    #   expect(isobib_item.workgroup.url).to eq 'www.iso.org'
    # end

    it "return relations" do
      expect(isobib_item.relations).to be_instance_of RelatonBib::DocRelationCollection
    end

    it "return replace realations" do
      expect(isobib_item.relations.replaces.length).to eq 0
    end

    it "return ICS" do
      expect(isobib_item.ics.first.fieldcode).to eq "35"
      expect(isobib_item.ics.first.description).to eq "IT applications in science"
    end
  end

  describe "get" do
    let(:hit_pages) { RelatonIso::IsoBibliography.search("19115") }

    it "gets a code" do
      mock_algolia 1
      mock_http_net 2
      results = RelatonIso::IsoBibliography.get("ISO 19115-1", nil, {}).to_xml
      expect(results).to include %(<bibitem id="ISO19115-1" type="standard">)
      expect(results).to include %(<on>2014</on>)
      expect(results.gsub(/<relation.*<\/relation>/m, "")).not_to include %(<on>2014</on>)
      expect(results).to include %(<docidentifier type="ISO">ISO 19115-1:2014</docidentifier>)
      expect(results).not_to include %(<docidentifier type="ISO">ISO 19115</docidentifier>)
    end

    it "gets an all-parts code" do
      mock_algolia 1
      mock_http_net 2
      results = RelatonIso::IsoBibliography.get("ISO 19115", nil, all_parts: true).to_xml bibdata: true
      expect(results).to include %(<project-number>ISO 19115 (all parts)</project-number>)
      expect(results).to include %(<docidentifier type="ISO">ISO 19115-1:2014</docidentifier>)
    end

    it "gets a keep-year code" do
      mock_algolia 1
      mock_http_net 2
      results = RelatonIso::IsoBibliography.get("ISO 19115-1", nil, keep_year: true).to_xml
      expect(results).to include %(<bibitem id="ISO19115-1-2014" type="standard">)
      expect(results.gsub(/<relation.*<\/relation>/m, "")).to include %(<on>2014</on>)
      expect(results).to include %(<docidentifier type="ISO">ISO 19115-1:2014</docidentifier>)
    end

    it "gets a code and year successfully" do
      mock_algolia 2
      mock_http_net 2
      results = RelatonIso::IsoBibliography.get("ISO 19115", "2003", {}).to_xml
      expect(results).to include %(<on>2003</on>)
      expect(results).not_to include %(<docidentifier type="ISO">ISO 19115-1:2003</docidentifier>)
      expect(results).to include %(<docidentifier type="ISO">ISO 19115:2003</docidentifier>)
    end

    it "gets reference with an year in a code" do
      mock_algolia 1
      mock_http_net 2
      results = RelatonIso::IsoBibliography.get("ISO 19115-1:2014", nil, {}).to_xml
      expect(results).to include %(<on>2014</on>)
    end

    it "gets a code and year unsuccessfully" do
      mock_algolia 4
      mock_http_net 2
      results = RelatonIso::IsoBibliography.get("ISO 19115", "2014", {})
      expect(results).to be nil
    end

    it "warns when a code matches a resource but the year does not" do
      mock_algolia 4
      mock_http_net 2
      expect { RelatonIso::IsoBibliography.get("ISO 19115", "2014", {}) }.
        to output(/There was no match for 2014, though there were matches found for 2003/).to_stderr 
    end

    it "warns when resource with part number not found on ISO website" do
      mock_algolia 4
      expect { RelatonIso::IsoBibliography.get("ISO 19115-30", "2014", {}) }.
        to output(/The provided document part may not exist, or the document may no longer be published in parts/).to_stderr 
    end

    it "warns when resource without part number not found on ISO website" do
      mock_algolia 4
      expect { RelatonIso::IsoBibliography.get("ISO 00000", "2014", {}) }.
        to output(/If you wanted to cite all document parts for the reference/).to_stderr
    end

    it "search ISO/IEC if search ISO failed" do
      VCR.use_cassette("iso_2382") do
        result = RelatonIso::IsoBibliography.get("ISO 2382", "2015", {})
        expect(result).not_to be nil
      end
    end
  end

  private

  # rubocop:disable Naming/UncommunicativeBlockParamName, Naming/VariableName
  # rubocop:disable Metrics/AbcSize
  # Mock xhr rquests to Algolia.
  def mock_algolia(num)
    index = double "index"
    expect(index).to receive(:search) do |text, facetFilters:, page: 0|
      expect(text).to be_instance_of String
      expect(facetFilters[0]).to eq "category:standard"
      JSON.parse File.read "spec/support/algolia_resp_page_#{page}.json"
    end.exactly(num).times
    expect(Algolia::Index).to receive(:new).with("all_en").at_least(:once).and_return index
  end
  # rubocop:enable Naming/UncommunicativeBlockParamName, Naming/VariableName
  # rubocop:enable Metrics/AbcSize

  # Mock http get pages requests.
  def mock_http_net(num)
    expect(Net::HTTP).to receive(:get_response).with(kind_of(URI)) do |uri|
      if uri.path =~ %r{\/contents\/}
        # When path is from json response then redirect.
        resp = Net::HTTPMovedPermanently.new "1.1", "301", "Moved Permanently"
        resp["location"] = "/standard/#{uri.path.match(/\d+\.html$/)}"
      else
        # In other case return success response with body.
        resp = double_resp uri
      end
      resp
    end.exactly(num).times
  end

  def double_resp(uri)
    resp = double "resp"
    expect(resp).to receive(:body) do
      File.read "spec/support/#{uri.path.tr('/', '_')}"
    end.at_least :once
    expect(resp).to receive(:code).and_return("200").at_most :once
    resp
  end
end
