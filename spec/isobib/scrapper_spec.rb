require "isobib/scrapper"

RSpec.describe Isobib::Scrapper do
  it "scrape parse pages" do
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
        resp = Net::HTTPMovedPermanently.new "1.1", "301", "Moved Permanently"
        resp["location"] = "/standard/#{uri.path.match(/\d+\.html$/)}"
      else
        resp = double "resp" # Net::HTTPOK.new "1.1", "200", "OK"
        expect(resp).to receive(:body) do
          File.read "spec/support/#{uri.path.gsub('/', '_')}"
        end
      end
      resp
    end.exactly(40).times

    results = Isobib::Scrapper.get("19115")
    expect(results).to be_instance_of Array
  end
end