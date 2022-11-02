RSpec.describe RelatonIso::Scrapper do
  it "follow http redirect" do
    resp1 = double "response"
    expect(resp1).to receive(:code).and_return "301"
    expect(resp1).to receive(:[]).with("location").and_return "/new_path"
    uri1 = URI "#{RelatonIso::Scrapper::DOMAIN}/path"
    expect(Net::HTTP).to receive(:get_response).with(uri1).and_return resp1

    resp2 = double "response"
    expect(resp2).to receive(:body).and_return(
      "<html><body></body></html>",
      "<html><body><strong>text</strong></body></html>",
      "<html><body><strong>text</strong></body></html>",
    )
    uri2 = URI "#{RelatonIso::Scrapper::DOMAIN}/new_path"
    expect(Net::HTTP).to receive(:get_response).with(uri2).and_return(resp2).twice

    RelatonIso::Scrapper.send(:get_page, "/path")
  end

  # it "returs default structured identifier" do
  #   doc = Nokogiri::HTML "<html><body></body></html>"
  #   si = RelatonIso::Scrapper.send(:fetch_structuredidentifier, doc)
  #   expect(si.id).to eq "?"
  # end

  it "returns TS type" do
    type = RelatonIso::Scrapper.send(:fetch_type, "ISO/TS 123")
    expect(type).to eq "technical-specification"
  end

  it "returns IWA type" do
    type = RelatonIso::Scrapper.send(:fetch_type, "IWA 123:2015")
    expect(type).to eq "international-workshop-agreement"
  end

  context "raises an error" do
    let(:hit) { double "hit", hit: { path: "1234" } }

    it "could not access" do
      expect(Net::HTTP).to receive(:get_response).and_raise SocketError
      expect do
        RelatonIso::Scrapper.parse_page(hit)
      end.to raise_error RelatonBib::RequestError
    end

    it "not found" do
      resp = double
      expect(resp).to receive(:code).and_return "404"
      expect(Net::HTTP).to receive(:get_response).and_return resp
      expect do
        RelatonIso::Scrapper.parse_page(hit)
      end.to raise_error RelatonBib::RequestError
    end
  end

  describe "#fetch_relaton_docids" do
    subject do
      expect(RelatonIso::Scrapper).to receive(:stage_code).and_return "90.93"
      described_class.fetch_relaton_docids(:doc, Pubid::Iso::Identifier.parse(pubid))
    end

    let(:source_pubid) { "ISO 19115:2003" }
    let(:pubid) { "ISO 19115:2003" }
    let(:urn) { "urn:iso:std:iso:19115" }
    let(:edition) { "3" }
    let(:stage) { 90.93 }

    it "returns PubID and URN RelatonBib document identifiers" do
      expect(subject.map(&:id)).to eq([pubid, urn])
    end
  end
end
