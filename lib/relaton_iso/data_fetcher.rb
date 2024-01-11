module RelatonIso
  # Fetch all the documents from ISO website.
  class DataFetcher
    #
    # Initialize data fetcher.
    #
    # @param [String] output output directory
    # @param [String] format format of output files (yaml, bibxml, xml)
    #
    def initialize(output, format)
      @output = output
      @format = format
      @ext = format.sub(/^bib/, "")
      @files = []
      @queue = ::Queue.new
      @mutex = Mutex.new
    end

    def index
      @index ||= Relaton::Index.find_or_create :iso, file: HitCollection::INDEXFILE
    end

    def iso_queue
      @iso_queue ||= RelatonIso::Queue.new
    end

    #
    # Initialize data fetcher and fetch data.
    #
    # @param [String] output output directory (default: "data")
    # @param [String] format format of output files. Allowed: yaml (default), bibxml, xml
    #
    # @return [void]
    #
    def self.fetch(output: "data", format: "yaml")
      t1 = Time.now
      puts "Started at: #{t1}"
      FileUtils.mkdir_p output
      new(output, format).fetch
      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end

    #
    # Go through all ICS and fetch all documents.
    #
    # @return [void]
    #
    def fetch # rubocop:disable Metrics/AbcSize
      puts "Scrapping ICS pages..."
      fetch_ics
      puts "[#{Time.now}] Scrapping documents..."
      fetch_docs
      iso_queue.save
      index.save
    end

    #
    # Fetch ICS page recursively and store all the links to documents in the iso_queue.
    #
    # @param [String] path path to ICS page
    #
    def fetch_ics
      threads = Array.new(3) { thread { |path| fetch_ics_page(path) } }
      fetch_ics_page "/standards-catalogue/browse-by-ics.html"
      sleep(1) until @queue.empty?
      threads.size.times { @queue << :END }
      threads.each(&:join)
    end

    def fetch_ics_page(path)
      resp = get_redirection path
      page = Nokogiri::HTML(resp.body)
      page.xpath("//td[@data-title='Standard and/or project']/div/div/a").each do |item|
        iso_queue.add_first item[:href].split("?").first
      end

      page.xpath("//td[@data-title='ICS']/a").each do |item|
        @queue << item[:href]
      end
    end

    #
    # Get the page from the given path. If the page is redirected, get the
    # page from the new path.
    #
    # @param [String] path path to the page
    #
    # @return [Net::HTTPOK] HTTP response
    #
    def get_redirection(path) # rubocop:disable Metrics/MethodLength
      try = 0
      uri = URI(Scrapper::DOMAIN + path)
      begin
        get_response uri
      rescue Net::OpenTimeout => e
        try += 1
        retry if check_try try, uri

        warn "Error fetching #{uri}"
        warn e.message
      end
    end

    def get_response(uri)
      resp = Net::HTTP.get_response(uri)
      resp.code == "302" ? get_redirection(resp["location"]) : resp
    end

    def check_try(try, uri)
      if try < 3
        warn "Timeout fetching #{uri}, retrying..."
        sleep 1
        true
      end
    end

    def fetch_docs
      threads = Array.new(3) { thread { |path| fetch_doc(path) } }
      iso_queue[0..10_000].each { |docpath| @queue << docpath }
      threads.size.times { @queue << :END }
      threads.each(&:join)
    end

    #
    # Fetch document from ISO website.
    #
    # @param [String] docpath document page path
    #
    # @return [void]
    #
    def fetch_doc(docpath)
      path = docpath.sub(/\.html$/, "")
      hit = Hit.new({ path: path }, nil)
      doc = Scrapper.parse_page hit
      @mutex.synchronize { save_doc doc, docpath }
    rescue StandardError => e
      warn "Error fetching document: #{Scrapper::DOMAIN}#{docpath}"
      warn e.message
      warn e.backtrace
    end

    #
    # save document to file.
    #
    # @param [RelatonIsoBib::IsoBibliographicItem] doc document
    #
    # @return [void]
    #
    def save_doc(doc, docpath) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      docid = doc.docidentifier.detect(&:primary)
      file_name = docid.id.gsub(/[\s\/:]+/, "-").downcase
      file = File.join @output, "#{file_name}.#{@ext}"
      if @files.include? file
        warn "Duplicate file #{file} for #{docid} from #{Scrapper::DOMAIN}#{docpath}"
      else
        @files << file
      end
      index.add_or_update docid.to_h, file
      File.write file, serialize(doc), encoding: "UTF-8"
      iso_queue.move_last docpath
    end

    #
    # Serialize document to string.
    #
    # @param [RelatonIsoBib::IsoBibliographicItem] doc document
    #
    # @return [String] serialized document
    #
    def serialize(doc)
      case @format
      when "yaml" then doc.to_hash.to_yaml
      when "bibxml" then doc.to_bibxml
      when "xml" then doc.to_xml bibdata: true
      end
    end

    private

    #
    # Create thread worker
    #
    # @return [Thread] thread
    #
    def thread
      Thread.new do
        while (path = @queue.pop) != :END
          yield path
        end
      end
    end
  end
end
