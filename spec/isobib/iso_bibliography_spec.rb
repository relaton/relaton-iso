require "isobib/iso_bibliography"
require "yaml"

RSpec.describe Isobib::IsoBibliography do

  it "return hit instances" do
    mock_algolia 2
    scrapper = Isobib::IsoBibliography.search("19155")
    hits = []
    scrapper.each do |hit|
      hits << hit
    end
    expect(hits.length).to eq 10
    expect(hits.first).to be_instance_of Isobib::Hit
  end

  it "fetch items from hit" do
    mock_algolia 1
    mock_http_net 8

    scrapper = Isobib::IsoBibliography.search("19155")
    hits = 0
    scrapper.each do |hit|
      expect(hit.fetch).to be_instance_of Isobib::IsoBibliographicItem
      hits += 1
      break if hits > 1
    end
  end

  describe "iso bibliography item" do
    let(:isobib_item) do
      mock_algolia 1
      mock_http_net 4
      scrapper = Isobib::IsoBibliography.search("19155")
      item = nil
      scrapper.each do |hit|
        item = hit.fetch
        break
      end
      item
    end

    it "return list of titles" do
      expect(isobib_item.title).to be_instance_of Array
    end

    it "return en title" do
      expect(isobib_item.title(lang: "en")).to be_instance_of Isobib::IsoLocalizedTitle
    end

    it "return string of title" do
      title = isobib_item.title(lang: "en")
      title_str = "#{title.title_intro} -- #{title.title_main} -- #{title.title_part}"
      expect(isobib_item.title(lang: "en").to_s).to eq title_str
    end

    it "return string of abstract" do
      formatted_string = isobib_item.abstract(lang: "en")
      expect(isobib_item.abstract(lang: "en").to_s).to eq (formatted_string&.content).to_s
    end

    it "return shortref" do
      shortref = "ISO #{isobib_item.docidentifier.project_number}-#{isobib_item.docidentifier.part_number}:#{isobib_item.copyright.from&.year}"
      expect(isobib_item.shortref).to eq shortref
    end

    it "return item urls" do
      expect(isobib_item.url).to match(/https:\/\/www\.iso\.org\/standard\/\d+\.html/)
      expect(isobib_item.url(:obp)).to be_instance_of String
      expect(isobib_item.url(:rss)).to match(/https:\/\/www\.iso\.org\/contents\/data\/standard\/\d{2}\/\d{2}\/\d+\.detail\.rss/)
    end

    it "return dates" do
      expect(isobib_item.dates.length).to eq 1
      expect(isobib_item.dates.first.type).to eq "published"
      expect(isobib_item.dates.first.from).to be_instance_of DateTime
    end

    it "filter dates by type" do
      expect(isobib_item.dates.filter(
        type: Isobib::BibliographicDateType::PUBLISHED).first.from
      ).to be_instance_of DateTime
    end

    it "return document status" do
      expect(isobib_item.status).to be_instance_of Isobib::IsoDocumentStatus
    end

    it "return workgroup" do
      expect(isobib_item.workgroup).to be_instance_of Isobib::IsoProjectGroup
    end

    it "workgroup equal first contributor entity" do
      expect(isobib_item.workgroup).to eq isobib_item.contributors.first.entity
    end

    it "return worgroup's url" do
      expect(isobib_item.workgroup.url).to eq "https://www.iso.org/committee/54904.html"
    end

    it "return relations" do
      expect(isobib_item.relations).to be_instance_of Isobib::DocRelationCollection
    end

    it "return replace realations" do
      expect(isobib_item.relations.replaces.length).to eq 0
    end

    it "return ICS" do
      expect(isobib_item.ics.first.fieldcode).to eq "35"
      expect(isobib_item.ics.first.description).to eq "IT applications in science"
    end
  end

  private

  # Mock xhr rquests to Algolia.
  def mock_algolia(n)
    index = double "index"
    expect(index).to receive(:search) do |text, facetFilters:, page: 0|
      expect(text).to be_instance_of String
      expect(facetFilters[0]).to eq "category:standard"
      JSON.parse File.read "spec/support/algolia_resp_page_#{page}.json"
    end.exactly(n).times
    expect(Algolia::Index).to receive(:new).with("all_en").and_return index
  end

  # Mock http get pages requests.
  def mock_http_net(n)
    expect(Net::HTTP).to receive(:get_response).with(kind_of URI) do |uri|
      if uri.path =~ /\/contents\//
        # When path is from json response then redirect.
        resp = Net::HTTPMovedPermanently.new "1.1", "301", "Moved Permanently"
        resp["location"] = "/standard/#{uri.path.match(/\d+\.html$/)}"
      else
        # In other case return success response with body.
        resp = double "resp"
        expect(resp).to receive(:body) do
          File.read "spec/support/#{uri.path.gsub('/', '_')}"
        end
        expect(resp).to receive(:code).and_return("200").at_most :once
      end
      resp
    end.exactly(n).times
  end
end