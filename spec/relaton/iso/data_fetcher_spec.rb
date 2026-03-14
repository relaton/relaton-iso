require "relaton/iso/data_fetcher"

describe Relaton::Iso::DataFetcher do
  subject { described_class.new "data", "yaml" }

  before do
    ENV["GITHUB_TOKEN"] = "token"
  end

  it "initializes" do
    data_fetcher = described_class.new "data", "bibxml"
    expect(data_fetcher.instance_variable_get(:@output)).to eq "data"
    expect(data_fetcher.instance_variable_get(:@format)).to eq "bibxml"
    expect(data_fetcher.instance_variable_get(:@ext)).to eq "xml"
    expect(data_fetcher.instance_variable_get(:@files)).to be_instance_of Set
  end

  context "::fetch" do
    let(:data_fetcher) { double "data_fetcher" }
    before { expect(data_fetcher).to receive(:fetch) }

    it "iso-rss, default output and format" do
      expect(described_class).to receive(:new).with("data", "yaml").and_return data_fetcher
      expect(FileUtils).to receive(:mkdir_p).with("data")
      described_class.fetch
    end

    it "iso-rss-all, output and format" do
      expect(described_class).to receive(:new).with("dir", "xml").and_return data_fetcher
      expect(FileUtils).to receive(:mkdir_p).with("dir")
      described_class.fetch(output: "dir", format: "xml")
    end
  end

  context "instance methods" do
    let(:index) { double "index" }
    let(:page) { double "page" }
    let(:item) { double "item" }
    let(:id) { Pubid::Iso::Identifier.parse "ISO/IEC 123" }
    let(:docid) { Relaton::Iso::Docidentifier.new content: id, type: "ISO", primary: true }
    let(:stage) { Relaton::Bib::Status::Stage.new content: "60" }
    let(:substage) { Relaton::Bib::Status::Stage.new content: "98" }
    let(:status) { Relaton::Bib::Status.new stage: stage, substage: substage }
    let(:edition) { Relaton::Bib::Edition.new content: "2" }
    let(:doc) { Relaton::Iso::ItemData.new docidentifier: [docid], edition: edition, status: status }

    it "#queue" do
      expect(subject.queue).to be_instance_of ::Queue
    end

    it "#mutex" do
      expect(subject.mutex).to be_instance_of Mutex
    end

    it "#iso_queue" do
      expect(subject.iso_queue).to be_instance_of Relaton::Iso::Queue
    end

    it "#fetch" do
      expect(subject).to receive(:fetch_ics).with(no_args)
      expect(subject).to receive(:fetch_docs).with(no_args)
      expect(subject.index).to receive(:save).with(no_args)
      expect(subject.iso_queue).to receive(:save).with(no_args)
      subject.fetch
    end

    it "#repot_errors" do
      errors = subject.instance_variable_get(:@errors)
      errors[:id] = false
      errors[:title] = true
      expect(subject.gh_issue).to receive(:create_issue)
      expect do
        subject.repot_errors
      end.to output("[relaton-iso] ERROR: Failed to fetch title\n").to_stderr_from_any_process
    end

    it "#fetch_ics" do
      expect(subject).to receive(:fetch_ics_page).with("/standards-catalogue/browse-by-ics.html")
      subject.send :fetch_ics
    end

    context "#fetch_ics_page" do
      let(:resp) { double "response", body: :html }

      context "successful" do
        before do
          expect(subject).to receive(:get_redirection)
            .with("/standards-catalogue/browse-by-ics.html").and_return resp
          expect(Nokogiri).to receive(:HTML).with(:html).and_return page
        end

        it "with ICS" do
          expect(page).to receive(:xpath).with("//td[@data-title='Standard and/or project']/div/div/a").and_return []
          expect(item).to receive(:[]).with(:href).and_return "/ics/01.html"
          expect(page).to receive(:xpath).with("//td[@data-title='ICS']/a").and_return [item]
          expect(subject.queue).to receive(:<<).with("/ics/01.html")
          subject.send :fetch_ics_page, "/standards-catalogue/browse-by-ics.html"
        end

        it "with documents" do
          expect(page).to receive(:xpath).with("//td[@data-title='Standard and/or project']/div/div/a").and_return [item]
          expect(item).to receive(:[]).with(:href).and_return "/standard/62510.html?browse=ics"
          expect(page).to receive(:xpath).with("//td[@data-title='ICS']/a").and_return []
          subject.send :fetch_ics_page, "/standards-catalogue/browse-by-ics.html"
          expect(subject.iso_queue[0]).to eq "/standard/62510.html"
        end
      end

      it "unsuccessful" do
        expect(subject).to receive(:get_redirection).with("/standards-catalogue/browse-by-ics.html").and_return nil
        expect do
          subject.send :fetch_ics_page, "/standards-catalogue/browse-by-ics.html"
        end.to output(
          /ERROR: Failed fetching ICS page https:\/\/www.iso\.org\/standards-catalogue\/browse-by-ics\.html/,
        ).to_stderr_from_any_process
      end
    end

    context "#parse_doc_links" do
      it "successful" do
        expect(item).to receive(:[]).with(:href).and_return "/standard/62510.html?browse=ics"
        expect(page).to receive(:xpath).with("//td[@data-title='Standard and/or project']/div/div/a")
          .and_return [item]
        subject.send :parse_doc_links, page # , "/standards-catalogue/browse-by-ics.html"
        expect(subject.iso_queue[0]).to eq "/standard/62510.html"
      end

      it "unsuccessful" do
        expect(page).to receive(:xpath).with("//td[@data-title='Standard and/or project']/div/div/a")
          .and_return []
        subject.send :parse_doc_links, page # , "/standards-catalogue/browse-by-ics.html"
        expect(subject.instance_variable_get(:@errors)).to eq doc_links: true
      end
    end

    context "#parse_ics_links" do
      it "successful" do
        expect(item).to receive(:[]).with(:href).and_return "/ics/01.html"
        expect(page).to receive(:xpath).with("//td[@data-title='ICS']/a").and_return [item]
        expect(subject.queue).to receive(:<<).with("/ics/01.html")
        subject.send :parse_ics_links, page # , "/standards-catalogue/browse-by-ics.html"
      end

      it "unsuccessful" do
        expect(page).to receive(:xpath).with("//td[@data-title='ICS']/a").and_return []
        subject.send :parse_ics_links, page # , "/standards-catalogue/browse-by-ics.html"
        expect(subject.instance_variable_get(:@errors)).to eq ics_links: true
      end
    end

    context "#get_redirection" do
      before do
        allow(URI).to receive(:parse).with("https://www.iso.org/link1").and_return :uri
      end

      it "successful" do
        resp = double "response", code: "302"
        expect(resp).to receive(:[]).with("location").and_return("/link2")
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
        expect(subject).to receive(:get_redirection).with("/link2").and_return resp
        allow(subject).to receive(:get_redirection).with("/link1").and_call_original
        expect(subject.send(:get_redirection, "/link1")).to eq resp
      end

      it "retry" do
        expect do
          resp = double "response", code: "200"
          expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Net::OpenTimeout).twice
          expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
          expect(subject.send(:get_redirection, "/link1")).to eq resp
        end.to output(/WARN: Timeout fetching uri, retrying.../).to_stderr_from_any_process
      end

      it "unsuccessful" do
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Net::OpenTimeout).exactly(3).times
        expect { subject.send(:get_redirection, "/link1") }
          .to output(/WARN: Failed fetching uri/).to_stderr_from_any_process
      end
    end

    it "#fetch_docs" do
      expect(subject.iso_queue).to receive(:[]).with(0..10_000).and_return %w[/page_path1 /page_path2]
      expect(subject.queue).to receive(:<<).with("/page_path1")
      expect(subject.queue).to receive(:<<).with("/page_path2")
      expect(subject.queue).to receive(:<<).with(:END).exactly(3).times.and_call_original
      subject.send :fetch_docs
    end

    context "#fetch_doc" do
      it "successful" do
        expect(Relaton::Iso::Scraper).to receive(:parse_page)
          .with("/page_path", errors: {}).and_return :doc
        expect(subject).to receive(:save_doc).with(:doc, "/page_path")
        subject.send :fetch_doc, "/page_path"
      end

      it "Open timeout" do
        expect(Relaton::Iso::Scraper).to receive(:parse_page).and_raise Net::OpenTimeout
        expect { subject.send :fetch_doc, "/page_path" }
          .to output(/WARN: Fail fetching document: https:\/\/www.iso\.org\/page_path/)
          .to_stderr_from_any_process
      end

      it "Read timeout" do
        expect(Relaton::Iso::Scraper).to receive(:parse_page).and_raise Net::ReadTimeout
        expect { subject.send :fetch_doc, "/page_path" }
          .to output(/WARN: Fail fetching document: https:\/\/www.iso\.org\/page_path/)
          .to_stderr_from_any_process
      end
    end

    context "#save_doc" do
      it "no file duplication" do
        subject.iso_queue.add_first "/page_path1.html"
        subject.iso_queue.add_first "/page_path2.html"
        expect(subject.index).to receive(:add_or_update).with(id.to_h, "data/iso-iec-123.yaml")
        expect(File).to receive(:write).with("data/iso-iec-123.yaml", /ISO\/IEC 123/, encoding: "UTF-8")
        subject.send :save_doc, doc, "/page_path1.html"
        expect(subject.iso_queue[0]).to eq "/page_path2.html"
      end

      context "file duplication" do
        let(:hash) { YAML.safe_load Relaton::Iso::Item.to_yaml(doc) }

        before do
          expect(File).to receive(:exist?).with("data/iso-iec-123.yaml").and_return true
          allow(File).to receive(:exist?).and_call_original
        end

        it "warn" do
          hash["status"] = { "stage" => { "content" => "60" }, "substage" => { "content" => "99" } }
          yaml = hash.to_yaml
          expect(File).to receive(:read).with("data/iso-iec-123.yaml", encoding: "UTF-8").and_return yaml
          subject.instance_variable_get(:@files).add "data/iso-iec-123.yaml"
          expect { subject.send :save_doc, doc, "/page_path.html" }
            .to output(/WARN: Duplicate file `data\/iso-iec-123\.yaml`/).to_stderr_from_any_process
        end

        it "rewrite" do
          hash["edition"] = { "content" => "1" }
          yaml = hash.to_yaml
          expect(File).to receive(:read).with("data/iso-iec-123.yaml", encoding: "UTF-8").and_return yaml
          expect(subject.index).to receive(:add_or_update).with(id.to_h, "data/iso-iec-123.yaml")
          expect(File).to receive(:write).with("data/iso-iec-123.yaml", /ISO\/IEC 123/, encoding: "UTF-8")
          subject.send :save_doc, doc, "/page_path.html"
        end
      end
    end

    context "#serialize" do
      it("yaml") { expect(subject.serialize(doc)).to include "content: ISO/IEC 123" }

      it "bibxml" do
        subject.instance_variable_set(:@format, "bibxml")
        expect(subject.serialize(doc)).to include '<reference anchor="ISO/IEC.123"'
      end

      it "xml" do
        subject.instance_variable_set(:@format, "xml")
        expect(subject.serialize(doc)).to include(
          '<docidentifier type="ISO" primary="true">ISO/IEC 123</docidentifier>',
        )
      end
    end
  end

  context "integration" do
    it "call fetch_doc asynchroniously" do
      expect(subject).to receive(:fetch_doc).with("/page_path.html")
      subject.iso_queue.add_first "/page_path.html"
      subject.send :fetch_docs
    end

    # it "fetch ics", vcr: "fetch_ics" do
    #   expect(subject).to receive(:fetch_ics_page).with("/standards-catalogue/browse-by-ics.html").and_call_original
    #   expect(subject).to receive(:fetch_ics_page).with("/ics/01.html").and_call_original
    #   expect(subject).to receive(:fetch_ics_page).with("/ics/01.020.html").and_call_original
    #   allow(subject).to receive(:fetch_ics_page).and_return nil
    #   subject.fetch_ics
    #   expect(subject.iso_queue[0..2]).to eq %w[/standard/62510.html /standard/45797.html /standard/71971.html]
    # end

    # it "fetch docs", vcr: "fetch_docs" do
    #   subject.iso_queue.add_first "/standard/62510.html"
    #   subject.iso_queue.add_first "/standard/45797.html"
    #   expect(subject).to receive(:save_doc).with(kind_of(RelatonIsoBib::IsoBibliographicItem), "/standard/62510.html")
    #   expect(subject).to receive(:save_doc).with(kind_of(RelatonIsoBib::IsoBibliographicItem), "/standard/45797.html")
    #   subject.fetch_docs
    #   threads = subject.instance_variable_get(:@threads)
    #   queue = subject.instance_variable_get(:@queue)
    #   threads.size.times { queue << :END }
    #   threads.each &:join
    # end
  end
end
