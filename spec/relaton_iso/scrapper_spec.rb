RSpec.describe RelatonIso::Scrapper do
  # it "returs default structured identifier" do
  #   doc = Nokogiri::HTML "<html><body></body></html>"
  #   si = RelatonIso::Scrapper.send(:fetch_structuredidentifier, doc)
  #   expect(si.id).to eq "?"
  # end

  it "returns TS type" do
    doctype = RelatonIso::Scrapper.send(:fetch_type, "ISO/TS 123")
    expect(doctype).to be_instance_of RelatonIsoBib::DocumentType
    expect(doctype.type).to eq "technical-specification"
  end

  it "returns IWA type" do
    doctype = RelatonIso::Scrapper.send(:fetch_type, "IWA 123:2015")
    expect(doctype.type).to eq "international-workshop-agreement"
  end

  context "raises an error" do
    let(:hit) { double "hit", hit: { path: "1234" } }

    it "could not access" do
      expect(Net::HTTP).to receive(:get_response).and_raise(SocketError).exactly(4).times
      expect do
        RelatonIso::Scrapper.parse_page(hit)
      end.to raise_error RelatonBib::RequestError
    end

    it "not found" do
      resp = double
      expect(resp).to receive(:code).and_return("404").exactly(4).times
      expect(Net::HTTP).to receive(:get_response).and_return(resp).exactly(4).times
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
    let(:isoref) { "ISO 19115:2003(E)" }
    let(:urn) { "urn:iso:std:iso:19115:stage-90.93" }
    let(:edition) { "3" }
    let(:stage) { 90.93 }

    it "returns PubID and URN RelatonBib document identifiers" do
      expect(subject.map(&:id)).to eq([pubid, isoref, urn])
    end
  end

  it "#isoref" do
    pubid = Pubid::Iso::Identifier.parse "ISO/DIS 14460"
    expect(subject.isoref(pubid)).to eq "ISO/DIS 14460(E)"
  end

  context "#get_page" do
    it "no error" do
      uri = double "uri", to_s: :url
      expect(described_class).to receive(:get_redirection).with("/path").and_return [:resp, uri]
      expect(described_class).to receive(:try_if_fail).with(:resp, uri).and_return :doc
      expect(described_class.send(:get_page, "/path")).to eq %i[doc url]
    end

    it "error" do
      expect(described_class).to receive(:get_redirection).with("/path").and_raise(SocketError).exactly(4).times
      expect { described_class.send(:get_page, "/path") }.to raise_error RelatonBib::RequestError
    end
  end

  context "#get_redirection" do
    before do
      expect(URI).to receive(:parse).with("#{RelatonIso::Scrapper::DOMAIN}/path").and_return :uri
    end
    it "found without redirection" do
      resp = double "response", code: "200"
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
      expect(described_class.send(:get_redirection, "/path")).to eq [resp, :uri]
    end

    it "found with redirection" do
      resp = double "response", code: "301"
      expect(resp).to receive(:[]).with("location").and_return "/new_path"
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
      expect(URI).to receive(:parse).with("#{RelatonIso::Scrapper::DOMAIN}/new_path").and_return :uri2
      resp2 = double "response 2", code: "200"
      expect(Net::HTTP).to receive(:get_response).with(:uri2).and_return resp2
      expect(described_class.send(:get_redirection, "/path")).to eq [resp2, :uri2]
    end

    it "not found" do
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return(double(code: "404")).exactly(4).times
      expect { described_class.send(:get_redirection, "/path") }.to raise_error RelatonBib::RequestError
    end

    context "retry" do
      let(:resp) { double(code: "200") }

      it do
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Errno::EPIPE).twice
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_return(resp)
        expect(described_class.send(:get_redirection, "/path")).to eq [resp, :uri]
      end

      it "limit" do
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Errno::EPIPE).exactly(3).times
        expect { described_class.send(:get_redirection, "/path") }.to raise_error Errno::EPIPE
      end
    end
  end

  context "#try_if_fail" do
    let(:resp) { double "response" }

    it "success" do
      expect(resp).to receive(:body).and_return(
        "<html><body></body></html>",
        "<html><body><main><div><section><div><div><div><nav><h1>ISO 123</h1>" \
          "</nav></div></div></div></section></div></main></body></html>",
      )
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
      doc = described_class.send(:try_if_fail, resp, :uri)
      expect(doc.at("h1").text).to eq "ISO 123"
    end

    it "fail" do
      expect(resp).to receive(:body).and_return("<html><body></body></html>").exactly(10).times
      expect(Net::HTTP).to receive(:get_response).with(:uri).and_return(resp).exactly(10).times
      expect do
        described_class.send(:try_if_fail, resp, :uri)
      end.to raise_error RelatonBib::RequestError
    end
  end

  context "#fetch_title" do
    it "intro, main, part" do
      doc = Nokogiri::HTML <<~HTML
        <nav role="navigation" aria-label="Children Navigation" class="heading-condensed nav-relatives">
          <div class="section-head section-back"></div>
          <h1><strike>ISO 19115-2:2009</strike></h1>
          <h2 class="mt-0 ">Geographic information</h2>
          <h3>Metadata</h3>
          <h4>Part 2: Extensions for imagery and gridded data</h4>
        </nav>
      HTML
      title = described_class.send(:fetch_title, doc, "en")
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first.title.content).to eq "Geographic information"
      expect(title.first.type).to eq "title-intro"
      expect(title[1].title.content).to eq "Metadata"
      expect(title[1].type).to eq "title-main"
      expect(title[2].title.content).to eq "Part 2: Extensions for imagery and gridded data"
      expect(title[2].type).to eq "title-part"
      expect(title[3].title.content).to eq "Geographic information - Metadata - Part 2: Extensions for imagery and gridded data"
      expect(title[3].type).to eq "main"
    end

    it "intro, main" do
      doc = Nokogiri::HTML <<~HTML
        <nav role="navigation" aria-label="Children Navigation" class="heading-condensed nav-relatives">
          <div class="section-head section-back"></div>
          <h1><strike>ISO 19115-2:2009</strike></h1>
          <h2 class="mt-0 ">Geographic information</h2>
          <h3>Metadata</h3>
        </nav>
      HTML
      title = described_class.send(:fetch_title, doc, "en")
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first.title.content).to eq "Geographic information"
      expect(title.first.type).to eq "title-intro"
      expect(title[1].title.content).to eq "Metadata"
      expect(title[1].type).to eq "title-main"
      expect(title[2].title.content).to eq "Geographic information - Metadata"
      expect(title[2].type).to eq "main"
    end

    it "main" do
      doc = Nokogiri::HTML <<~HTML
        <nav role="navigation" aria-label="Children Navigation" class="heading-condensed nav-relatives">
          <div class="section-head section-back"></div>
          <h1><strike>ISO 19115-2:2009</strike></h1>
          <h2 class="mt-0 ">Geographic information</h2>
        </nav>
      HTML
      title = described_class.send(:fetch_title, doc, "en")
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first.title.content).to eq "Geographic information"
      expect(title.first.type).to eq "title-main"
      expect(title[1].title.content).to eq "Geographic information"
      expect(title[1].type).to eq "main"
    end

    it "split single title" do
      doc = Nokogiri::HTML <<~HTML
        <nav role="navigation" aria-label="Children Navigation" class="heading-condensed nav-relatives">
          <div class="section-head section-back"></div>
          <h1><strike>ISO 19115-2:2009</strike></h1>
          <h2 class="mt-0 ">Geographic information - Metadata - Part 2: Extensions for imagery and gridded data</h2>
        </nav>
      HTML
      title = described_class.send(:fetch_title, doc, "en")
      expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
      expect(title.first.title.content).to eq "Geographic information"
      expect(title.first.type).to eq "title-intro"
      expect(title[1].title.content).to eq "Metadata"
      expect(title[1].type).to eq "title-main"
      expect(title[2].title.content).to eq "Part 2: Extensions for imagery and gridded data"
      expect(title[2].type).to eq "title-part"
      expect(title[3].title.content).to eq "Geographic information - Metadata - Part 2: Extensions for imagery and gridded data"
      expect(title[3].type).to eq "main"
    end
  end

  context "#fetch_copyright" do
    it "returns copyright" do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <main>
              <div>
                <section>
                  <div>
                    <div>
                      <div>
                        <nav class="heading-condensed nav-relatives">
                          <h1>ISO 123</h1>
                        </nav>
                      </div>
                    </div>
                  <div>
                    <div>
                      <ul>
                        <li>
                          <div>
                            <span itemprop="releaseDate">2017-01-01</span>
                          </div>
                        </li>
                      </ul>
                    </div>
                  </div>
                </section>
              </div>
            </main>
          </body>
        </html>
      HTML
      expect(described_class.send(:fetch_copyright, doc)).to eq [{ from: "2017", owner: [{ name: "ISO" }]}]
    end
  end
end
