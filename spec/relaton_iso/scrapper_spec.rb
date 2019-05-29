RSpec.describe RelatonIso::Scrapper do
  it "follow http redirect" do
    resp1 = double "response"
    expect(resp1).to receive(:code).and_return "301"
    expect(resp1).to receive(:[]).with("location").and_return "/new_path"
    uri1 = URI RelatonIso::Scrapper::DOMAIN + "/path"
    expect(Net::HTTP).to receive(:get_response).with(uri1).and_return resp1

    resp2 = double "response"
    expect(resp2).to receive(:body).and_return(
      "<html><body></body></html>",
      "<html><body><strong>text</strong></body></html>",
      "<html><body><strong>text</strong></body></html>",
    )
    uri2 = URI RelatonIso::Scrapper::DOMAIN + "/new_path"
    expect(Net::HTTP).to receive(:get_response).with(uri2).and_return(resp2).twice

    RelatonIso::Scrapper.send(:get_page, "/path")
  end

  it "returs default structured identifier" do
    doc = Nokogiri::HTML "<html><body></body></html>"
    si = RelatonIso::Scrapper.send(:fetch_structuredidentifier, doc)
    expect(si.id).to eq "?"
  end

  it "returns TS type" do
    type = RelatonIso::Scrapper.send(:fetch_type, "ISO/TS 123")
    expect(type).to eq "technical-specification"
  end

  it "returns IWA type" do
    type = RelatonIso::Scrapper.send(:fetch_type, "IWA 123:2015")
    expect(type).to eq "international-workshop-agreement"
  end

  it "returns title main only" do
    doc = Nokogiri::HTML <<END_HTML
      <html>
        <body>
          <h3 itemprop="description">Main</h3>
        </body>
      </html>
END_HTML

    title = RelatonIso::Scrapper.send :fetch_title, doc, "en"
    expect(title[:title_main]).to eq "Main"
  end

  it "returns title main and part" do
    doc = Nokogiri::HTML <<END_HTML
      <html>
        <body>
          <h3 itemprop="description">Main -- Part 1: Description</h3>
        </body>
      </html>
END_HTML

    title = RelatonIso::Scrapper.send :fetch_title, doc, "en"
    expect(title[:title_main]).to eq "Main"
    expect(title[:title_part]).to eq "Part 1: Description"
  end
end
