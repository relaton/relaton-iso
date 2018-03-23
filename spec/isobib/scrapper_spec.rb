require "isobib/scrapper"

RSpec.describe Isobib::Scrapper do
  it "parse pages" do
    index = double "index"
    expect(index).to receive(:search).with(kind_of(String),
                                           facetFilters: ["category:standard"],
                                           page: kind_of(Integer)
                                           ) do |text, facetFilters:, page:|
      JSON.parse File.read "spec/support/algolia_resp_page_#{page}.json"
    end.twice

    expect(Algolia::Index).to receive(:new).with("all_en").and_return index

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

    results = Isobib::Scrapper.get("19115")
    expect(results).to be_instance_of Array
    expect(results.first[:docid]).to be_instance_of Hash
    expect(results.first[:edition]).to be_instance_of String
    expect(results.first[:titles]).to be_instance_of Array
    expect(results.first[:type]).to eq "internationalStandard"
    expect(results.first[:docstatus]).to be_instance_of Hash
    expect(results.first[:ics]).to be_instance_of Array
    expect(results.first[:dates]).to be_instance_of Array
  end
end