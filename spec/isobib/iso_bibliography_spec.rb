# frozen_string_literal: true

require 'isobib/iso_bibliography'

RSpec.describe Isobib::IsoBibliography do
  let(:hit_pages) { Isobib::IsoBibliography.search('19115') }

  it 'return HitPages instance' do
    mock_algolia 2
    hit_pages = Isobib::IsoBibliography.search('19155')
    expect(hit_pages).to be_instance_of Isobib::HitPages
    expect(hit_pages.first).to be_instance_of Isobib::HitCollection
    expect(hit_pages[1]).to be_instance_of Isobib::HitCollection
  end

  it 'fetch hits of page' do
    mock_algolia 1
    mock_http_net 10

    hit_pages = Isobib::IsoBibliography.search('19115')
    expect(hit_pages.first.fetched).to be_falsy
    expect(hit_pages[0].fetch).to be_instance_of Isobib::HitCollection
    expect(hit_pages.first.fetched).to be_truthy
    expect(hit_pages[0].first).to be_instance_of Isobib::Hit
  end

  it 'search and fetch' do
    mock_algolia 2
    mock_http_net 20
    results = Isobib::IsoBibliography.search_and_fetch('19115')
    expect(results.size).to be 10
  end

  it 'return string of hit' do
    mock_algolia 1
    hit_pages = Isobib::IsoBibliography.search('19115')
    expect(hit_pages.first[0].to_s).to eq '<Isobib::Hit:'\
      "#{format('%#.14x', hit_pages.first[0].object_id << 1)} "\
      '@text="19115" @fullIdentifier="" @matchedWords=["19115"] '\
      '@category="standard" @title="ISO 19115-1:2014/Amd 1:2018 ">'
  end

  it 'return xml of hit' do
    mock_algolia 1
    mock_http_net 2
    hit_pages = Isobib::IsoBibliography.search('19115')
    file_path = 'spec/support/hit.xml'
    File.write file_path, hit_pages.first[2].to_xml unless File.exist? file_path
    expect(hit_pages.first[2].to_xml).to be_equivalent_to File.read file_path
  end

  it 'return last page of hits' do
    mock_algolia 2
    expect(hit_pages.last).to be_instance_of Isobib::HitCollection
  end

  it 'iteration pages of hits' do
    mock_algolia 2
    expect(hit_pages.size).to eq 2
    pages = hit_pages.map { |p| p }
    expect(pages.size).to eq 2
    hit_pages.each { |p| expect(p).to be_instance_of Isobib::HitCollection }
  end

  it 'return string of hit pages' do
    mock_algolia 1
    expect(hit_pages.to_s).to eq(
      "<Isobib::HitPages:#{format('%#.14x', hit_pages.object_id << 1)} "\
      '@text=19115 @pages=2>'
    )
  end

  # it 'return documents in xml format', broken: true do
  #   mock_algolia 2
  #   mock_http_net 20
  #   file_path = 'spec/support/hit_pages.xml'
  #   File.write file_path, hit_pages.to_xml unless File.exist? file_path
  #   expect(hit_pages.to_xml).to eq File.read file_path
  # end

  describe 'iso bibliography item' do
    let(:isobib_item) do
      mock_algolia 1
      mock_http_net 2
      hit_pages = Isobib::IsoBibliography.search('19155')
      hit_pages.first.first.fetch
    end

    it 'return list of titles' do
      expect(isobib_item.title).to be_instance_of Array
    end

    it 'return en title' do
      expect(isobib_item.title(lang: 'en'))
        .to be_instance_of IsoBibItem::IsoLocalizedTitle
    end

    it 'return string of title' do
      title = isobib_item.title(lang: 'en')
      title_str = title.title_main
      title_str = "#{title.title_intro} -- #{title_str}" if title.title_intro && !title.title_intro.empty?
      title_str = "#{title_str} -- #{title.title_part}" if title.title_part && !title.title_part.empty?
      expect(isobib_item.title(lang: 'en').to_s).to eq title_str
    end

    it 'return string of abstract' do
      formatted_string = isobib_item.abstract(lang: 'en')
      expect(isobib_item.abstract(lang: 'en').to_s)
        .to eq formatted_string&.content.to_s
    end

    it 'return shortref' do
      pubdate = isobib_item.dates.select { |d| d.type == "published" }
      shortref = "ISO #{isobib_item.docidentifier.project_number}-"\
        "#{isobib_item.docidentifier.part_number}:"\
        "#{pubdate&.first&.on&.year}"
      expect(isobib_item.shortref).to eq shortref
    end

    it 'return item urls' do
      url_regex = %r{https:\/\/www\.iso\.org\/standard\/\d+\.html}
      expect(isobib_item.url).to match(url_regex)
      expect(isobib_item.url(:obp)).to be_instance_of String
      rss_regex = %r{https:\/\/www\.iso\.org\/contents\/data\/standard\/\d{2}
      \/\d{2}\/\d+\.detail\.rss}x
      expect(isobib_item.url(:rss)).to match(rss_regex)
      end

      it 'return dates' do
      expect(isobib_item.dates.length).to eq 1
      expect(isobib_item.dates.first.type).to eq 'published'
      expect(isobib_item.dates.first.on).to be_instance_of Time
    end

    # it 'filter dates by type' do
    #   expect(isobib_item.dates.filter(type: 'published').first.from)
    #     .to be_instance_of(Time)
    # end

    it 'return document status' do
      expect(isobib_item.status).to be_instance_of IsoBibItem::IsoDocumentStatus
    end

    it 'return workgroup' do
      expect(isobib_item.workgroup).to be_instance_of IsoBibItem::IsoProjectGroup
    end

    # it 'workgroup equal first contributor entity' do
    #   expect(isobib_item.workgroup).to eq isobib_item.contributors.first.entity
    # end

    # it 'return worgroup\'s url' do
    #   expect(isobib_item.workgroup.url).to eq 'www.iso.org'
    # end

    it 'return relations' do
      expect(isobib_item.relations)
        .to be_instance_of IsoBibItem::DocRelationCollection
    end

    it 'return replace realations' do
      expect(isobib_item.relations.replaces.length).to eq 0
    end

    it 'return ICS' do
      expect(isobib_item.ics.first.fieldcode).to eq '35'
      expect(isobib_item.ics.first.description)
        .to eq 'IT applications in science'
    end
  end

  describe 'get' do
    let(:hit_pages) { Isobib::IsoBibliography.search('19115') }

    it "gets a code" do
      mock_algolia 1
      mock_http_net 2
      results = Isobib::IsoBibliography.get('ISO 19115-1', nil, {})
      expect(results).to include %(<bibitem type="international-standard" id="ISO19115-1">)
      expect(results).to include %(<on>2014</on>)
      expect(results).to include %(<docidentifier>ISO 19115-1</docidentifier>)
      expect(results).not_to include %(<docidentifier>ISO 19115</docidentifier>)
    end

    it "gets an all-parts code" do
      mock_algolia 1
      mock_http_net 2
      results = Isobib::IsoBibliography.get('ISO 19115', nil, {all_parts: true})
      expect(results).to include %(<bibitem type="international-standard" id="ISO19115">)
      expect(results).to include %(<docidentifier>ISO 19115-1</docidentifier>)
      expect(results).to include %(<docidentifier>ISO 19115: All Parts</docidentifier>)
    end

    it "gets a code and year successfully" do
      mock_algolia 2
      mock_http_net 2
      results = Isobib::IsoBibliography.get('ISO 19115', "2003", {})
      expect(results).to include %(<on>2003</on>)
      expect(results).not_to include %(<docidentifier>ISO 19115-1</docidentifier>)
      expect(results).to include %(<docidentifier>ISO 19115</docidentifier>)
    end

    it "gets a code and year unsuccessfully" do
      mock_algolia 2
      mock_http_net 2
      results = Isobib::IsoBibliography.get('ISO 19115', "2014", {})
      expect(results).to be nil
    end

    it "warns when a code matches a resource but the year does not" do
      mock_algolia 2
      mock_http_net 2
      expect { Isobib::IsoBibliography.get('ISO 19115', "2014", {}) }.to output(/There was no match for 2014, though there were matches found for 2003/).to_stderr 
    end

    it "warns when resource with part number not found on ISO website" do
      mock_algolia 2
      expect { results = Isobib::IsoBibliography.get('ISO 19115-30', "2014", {}) }.to output(/The provided document part may not exist, or the document may no longer be published in parts/).to_stderr 
    end

    it "warns when resource without part number not found on ISO website" do
      mock_algolia 2
      expect { results = Isobib::IsoBibliography.get('ISO 00000', "2014", {}) }.to output(/If you wanted to cite all document parts for the reference/).to_stderr
    end

    it "gets a frozen reference for IEV" do
      results = Isobib::IsoBibliography.get('IEV', nil, {})
      expect(results).to include %(<bibitem type="international-standard" id="IEV">)
    end

  end

  private

  # rubocop:disable Naming/UncommunicativeBlockParamName, Naming/VariableName
  # rubocop:disable Metrics/AbcSize
  # Mock xhr rquests to Algolia.
  def mock_algolia(num)
    index = double 'index'
    expect(index).to receive(:search) do |text, facetFilters:, page: 0|
      expect(text).to be_instance_of String
      expect(facetFilters[0]).to eq 'category:standard'
      JSON.parse File.read "spec/support/algolia_resp_page_#{page}.json"
    end.exactly(num).times
    expect(Algolia::Index).to receive(:new).with('all_en').and_return index
  end
  # rubocop:enable Naming/UncommunicativeBlockParamName, Naming/VariableName
  # rubocop:enable Metrics/AbcSize

  # Mock http get pages requests.
  def mock_http_net(num)
    expect(Net::HTTP).to receive(:get_response).with(kind_of(URI)) do |uri|
      if uri.path.match? %r{\/contents\/}
        # When path is from json response then redirect.
        resp = Net::HTTPMovedPermanently.new '1.1', '301', 'Moved Permanently'
        resp['location'] = "/standard/#{uri.path.match(/\d+\.html$/)}"
      else
        # In other case return success response with body.
        resp = double_resp uri
      end
      resp
    end.exactly(num).times
  end

  def double_resp(uri)
    resp = double 'resp'
    expect(resp).to receive(:body) do
      File.read "spec/support/#{uri.path.tr('/', '_')}"
    end.at_least :once
    expect(resp).to receive(:code).and_return('200').at_most :once
    resp
  end
end
