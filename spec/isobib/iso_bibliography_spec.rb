require "isobib/iso_bibliography"
require "yaml"

RSpec.describe Isobib::IsoBibliography do
  # let(:results) do
    # expect(Isobib::Scrapper).to receive(:get).with(kind_of(String)) do
    #   items = YAML.load_file "spec/support/iso_bibliographic_items.yml"
    #   JSON.parse items.to_json, symbolize_names: true
    # end

    # Isobib::IsoBibliography.search("19155")
  # end

  before(:all) do
    RSpec::Mocks.with_temporary_scope do
      # Mock xhr requests to Algolia.
      index = double "index"
      expect(index).to receive(:search).with(kind_of(String),
                                            facetFilters: ["category:standard"],
                                            page: kind_of(Integer)
                                            ) do |text, facetFilters:, page:|
        JSON.parse File.read "spec/support/algolia_resp_page_#{page}.json"
      end.twice
      expect(Algolia::Index).to receive(:new).with("all_en").and_return index

      # Mock http get pages requests.
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
      end.exactly(40).times

      @results = Isobib::IsoBibliography.search("19155")
    end
  end

  it "search for iso bibliongraphic items" do
    expect(@results.length).to eq 10
  end

  it "return item from collection" do
    expect(@results.first).to be_instance_of Isobib::IsoBibliographicItem
    expect(@results[1]).to be_instance_of Isobib::IsoBibliographicItem
  end

  it "return list of titles" do
    expect(@results.first.title).to be_instance_of Array
  end

  it "return en title" do
    expect(@results.first.title(lang: "en")).to be_instance_of Isobib::IsoLocalizedTitle
  end

  it "return string of title" do
    title = @results.first.title(lang: "en")
    title_str = "#{title.title_intro} -- #{title.title_main} -- #{title.title_part}"
    expect(@results.first.title(lang: "en").to_s).to eq title_str
  end

  it "return string of abstract" do
    formatted_string = @results.first.abstract(lang: "en")
    expect(@results.first.abstract(lang: "en").to_s).to eq (formatted_string&.content).to_s
  end

  it "return shortref" do
    iso_item = @results.first
    shortref = "ISO #{iso_item.docidentifier.project_number}-#{iso_item.docidentifier.part_number}:#{iso_item.copyright.from&.year}"
    expect(@results.first.shortref).to eq shortref
  end

  it "return item urls" do
    expect(@results.first.url).to match(/https:\/\/www\.iso\.org\/standard\/\d+\.html/)
    expect(@results.first.url(:obp)).to be_instance_of String
    expect(@results.first.url(:rss)).to match(/https:\/\/www\.iso\.org\/contents\/data\/standard\/\d{2}\/\d{2}\/\d+\.detail\.rss/)
  end

  it "return dates" do
    expect(@results.first.dates.length).to eq 1
    expect(@results.first.dates.first.type).to eq "published"
    expect(@results.first.dates.first.from).to be_instance_of DateTime
  end

  it "filter dates by type" do
    expect(@results.first.dates.filter(
      type: Isobib::BibliographicDateType::PUBLISHED).first.from
     ).to be_instance_of DateTime
  end

  it "return document status" do
    expect(@results.first.status).to be_instance_of Isobib::IsoDocumentStatus
  end

  it "return workgroup" do
    expect(@results.first.workgroup).to be_instance_of Isobib::IsoProjectGroup
  end

  it "workgroup equal first contributor entity" do
    expect(@results.first.workgroup).to eq @results.first.contributors.first.entity
  end

  it "return worgroup's url" do
    expect(@results.first.workgroup.url).to eq "https://www.iso.org/committee/54904.html"
  end

  it "return relations" do
    expect(@results.first.relations).to be_instance_of Isobib::DocRelationCollection
  end

  it "return replace realations" do
    expect(@results.first.relations.replaces.length).to eq 0
  end

  it "return ICS" do
    expect(@results.first.ics.first.fieldcode).to eq "35"
    expect(@results.first.ics.first.description).to eq "IT applications in science"
  end
end