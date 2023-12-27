describe RelatonIso::DataFetcher do
  subject { described_class.new "data", "yaml" }

  it "initializes" do
    data_fetcher = described_class.new "data", "bibxml"
    expect(data_fetcher.instance_variable_get(:@output)).to eq "data"
    expect(data_fetcher.instance_variable_get(:@format)).to eq "bibxml"
    expect(data_fetcher.instance_variable_get(:@ext)).to eq "xml"
    expect(data_fetcher.instance_variable_get(:@files)).to eq []
  end

  context "fetch" do
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
    let(:iso_queue) { double "iso_queue" }
    let(:index) { double "index" }

    before do
      allow(RelatonIso::Queue).to receive(:new).and_return iso_queue
    end

    it "#iso_queue" do
      expect(subject.iso_queue).to be iso_queue
    end

    it "#fetch" do
      expect(subject).to receive(:fetch_ics).with(no_args)
      expect(subject).to receive(:fetch_docs).with(no_args)
      expect(subject.index).to receive(:save).with(no_args)
      expect(iso_queue).to receive(:save).with(no_args)
      subject.fetch
    end

    it "#fetch_ics" do
      expect(subject).to receive(:fetch_ics_page).with("/standards-catalogue/browse-by-ics.html")
      subject.fetch_ics
    end

    context "#fetch_ics_page" do
      let(:resp) { double "response", body: :html }
      let(:page) { double "page" }
      let(:item) { double "item" }
      let(:queue) { subject.instance_variable_get(:@queue) }

      before do
        expect(subject).to receive(:get_redirection).with("/standards-catalogue/browse-by-ics.html").and_return resp
        expect(Nokogiri).to receive(:HTML).with(:html).and_return page
      end

      it "with ICS" do
        expect(page).to receive(:xpath).with("//td[@data-title='Standard and/or project']/div/div/a").and_return []
        expect(item).to receive(:[]).with(:href).and_return "/ics/01.html"
        expect(page).to receive(:xpath).with("//td[@data-title='ICS']/a").and_return [item]
        expect(queue).to receive(:<<).with("/ics/01.html")
        subject.fetch_ics_page "/standards-catalogue/browse-by-ics.html"
      end

      it "with documents" do
        expect(page).to receive(:xpath).with("//td[@data-title='Standard and/or project']/div/div/a").and_return [item]
        expect(item).to receive(:[]).with(:href).and_return "/standard/62510.html?browse=ics"
        expect(page).to receive(:xpath).with("//td[@data-title='ICS']/a").and_return []
        expect(iso_queue).to receive(:add_first).with("/standard/62510.html")
        subject.fetch_ics_page "/standards-catalogue/browse-by-ics.html"
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
        expect(subject.get_redirection("/link1")).to eq resp
      end

      it "retry" do
        expect do
          resp = double "response", code: "200"
          expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Net::OpenTimeout).twice
          expect(Net::HTTP).to receive(:get_response).with(:uri).and_return resp
          expect(subject.get_redirection("/link1")).to eq resp
        end.to output(/Timeout fetching https:\/\/www\.iso\.org\/link1, retrying.../).to_stderr
      end

      it "unsuccessful" do
        expect(Net::HTTP).to receive(:get_response).with(:uri).and_raise(Net::OpenTimeout).exactly(3).times
        expect do
          subject.get_redirection("/link1")
        end.to output(/Error fetching https:\/\/www\.iso\.org\/link1/).to_stderr
      end
    end

    it "#fetch_docs" do
      expect(iso_queue).to receive(:[]).with(0..10_000).and_return %w[/page_path1 /page_path2]
      queue = subject.instance_variable_get(:@queue)
      expect(queue).to receive(:<<).with("/page_path1")
      expect(queue).to receive(:<<).with("/page_path2")
      expect(queue).to receive(:<<).with(:END).exactly(3).times.and_call_original
      subject.fetch_docs
    end

    context "#fetch_doc" do
      before do
        expect(RelatonIso::Hit).to receive(:new).with({ path: "/page_path" }, nil).and_return :hit
      end

      it "successful" do
        expect(RelatonIso::Scrapper).to receive(:parse_page).with(:hit).and_return :doc
        expect(subject).to receive(:save_doc).with(:doc, "/page_path.html")
        subject.fetch_doc "/page_path.html"
      end

      it "unsuccessful" do
        expect(RelatonIso::Scrapper).to receive(:parse_page).and_raise StandardError
        expect do
          subject.fetch_doc "/page_path.html"
        end.to output(/Error fetching document: https:\/\/www.iso\.org\/page_path\.html/).to_stderr
      end
    end

    context "#save_doc" do
      let(:doc) do
        id = Pubid::Iso::Identifier.parse "ISO/IEC 123"
        double "doc", docidentifier: [double(id: id, primary: true)]
      end

      before do
        expect(subject.index).to receive(:add_or_update).with("ISO/IEC 123", "data/iso-iec-123.yaml")
        expect(subject).to receive(:serialize).with(doc).and_return :content
        expect(File).to receive(:write).with("data/iso-iec-123.yaml", :content, encoding: "UTF-8")
        expect(iso_queue).to receive(:move_last).with("/page_path.html")
      end

      it "no file duplication" do
        subject.save_doc doc, "/page_path.html"
        expect(subject.instance_variable_get(:@files)).to eq ["data/iso-iec-123.yaml"]
      end

      it "file duplication" do
        subject.instance_variable_set(:@files, ["data/iso-iec-123.yaml"])
        expect do
          subject.save_doc doc, "/page_path.html"
        end.to output(/Duplicate file data\/iso-iec-123\.yaml/).to_stderr
      end
    end

    context "#serialize" do
      let(:doc) { double "doc" }

      it "yaml" do
        expect(doc).to receive_message_chain(:to_hash, :to_yaml).and_return :yaml
        expect(subject.serialize(doc)).to be :yaml
      end

      it "bibxml" do
        subject.instance_variable_set(:@format, "bibxml")
        expect(doc).to receive(:to_bibxml).and_return :bibxml
        expect(subject.serialize(doc)).to be :bibxml
      end

      it "xml" do
        subject.instance_variable_set(:@format, "xml")
        expect(doc).to receive(:to_xml).with(bibdata: true).and_return :xml
        expect(subject.serialize(doc)).to be :xml
      end
    end
  end

  context "integration" do
    it "call fetch_doc asynchroniously" do
      expect(subject).to receive(:fetch_doc).with("/page_path.html")
      iso_queue = double "iso_queue"
      expect(iso_queue).to receive(:[]).with(0..10_000).and_return ["/page_path.html"]
      expect(subject).to receive(:iso_queue).and_return iso_queue
      subject.fetch_docs
    end

    it "fetch ics", vcr: "fetch_ics" do
      # expect(subject).to receive(:fetch_ics_page).with("/standards-catalogue/browse-by-ics.html").and_call_original
      # expect(subject).to receive(:fetch_ics_page).with("/ics/01.html").and_call_original
      # expect(subject).to receive(:fetch_ics_page).with("/ics/01.020.html").and_call_original
      # allow(subject).to receive(:fetch_ics_page).and_return nil
      # subject.fetch_ics
      # expect(subject.iso_queue[0..2]).to eq %w[/standard/62510.html /standard/45797.html /standard/71971.html]
    end

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
