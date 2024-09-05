module RelatonIso
  # Fetch all the documents from ISO website.
  class DataFetcher
    #
    # Initialize data fetcher.
    #
    # @param [String] output output directory
    # @param [String] format format of output files (yaml, bibxml, xml)
    #
    def initialize(output, format) # rubocop:disable Metrics/AbcSize
      @output = output
      @format = format
      @ext = format.sub(/^bib/, "")
      @files = Set.new
      @queue = ::Queue.new
      @mutex = Mutex.new
      @gh_issue = Relaton::Logger::Channels::GhIssue.new "relaton/relaton-iso", "Error fetching ISO documents"
      Relaton.logger_pool[:gh_issue] = Relaton::Logger::Log.new(@gh_issue, levels: [:error])
      @errors = Hash.new(true)
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
      Util.info "Started at: #{t1}"
      FileUtils.mkdir_p output
      new(output, format).fetch
      t2 = Time.now
      Util.info "Stopped at: #{t2}"
      Util.info "Done in: #{(t2 - t1).round} sec."
    end

    #
    # Go through all ICS and fetch all documents.
    #
    # @return [void]
    #
    def fetch # rubocop:disable Metrics/AbcSize
      Util.info "Scrapping ICS pages..."
      fetch_ics
      Util.info "(#{Time.now}) Scrapping documents..."
      fetch_docs
      iso_queue.save
      # index.sort! { |a, b| compare_docids a, b }
      index.save
      repot_errors
    end

    def repot_errors
      @errors.select { |_, v| v }.each_key do |k|
        Util.error "Failed to fetch #{k}"
      end
      @gh_issue.create_issue
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
      unless resp
        Util.error "Failed fetching ICS page #{url(path)}"
        return
      end

      page = Nokogiri::HTML(resp.body)
      parse_doc_links page
      parse_ics_links page
    end

    def parse_doc_links(page)
      doc_links = page.xpath "//td[@data-title='Standard and/or project']/div/div/a"
      @errors[:doc_links] &&= doc_links.empty?
      doc_links.each { |item| iso_queue.add_first item[:href].split("?").first }
    end

    def parse_ics_links(page)
      ics_links = page.xpath("//td[@data-title='ICS']/a")
      @errors[:ics_links] &&= ics_links.empty?
      ics_links.each { |item| @queue << item[:href] }
    end

    def url(path)
      Scrapper::DOMAIN + path
    end

    #
    # Get the page from the given path. If the page is redirected, get the
    # page from the new path.
    #
    # @param [String] path path to the page
    #
    # @return [Net::HTTPOK, nil] HTTP response
    #
    def get_redirection(path) # rubocop:disable Metrics/MethodLength
      try = 0
      uri = URI url(path)
      begin
        get_response uri
      rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
        try += 1
        retry if check_try try, uri

        Util.warn "Failed fetching #{uri}, #{e.message}"
      end
    end

    def get_response(uri)
      resp = Net::HTTP.get_response(uri)
      resp.code == "302" ? get_redirection(resp["location"]) : resp
    end

    def check_try(try, uri)
      if try < 3
        Util.warn "Timeout fetching #{uri}, retrying..."
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
      doc = Scrapper.parse_page docpath, errors: @errors
      @mutex.synchronize { save_doc doc, docpath }
    rescue StandardError => e
      Util.warn "Fail fetching document: #{url(docpath)}\n#{e.message}\n#{e.backtrace}"
    end

    # def compare_docids(id1, id2)
    #   Pubid::Iso::Identifier.create(**id1).to_s <=> Pubid::Iso::Identifier.create(**id2).to_s
    # end

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
      if File.exist?(file)
        rewrite_with_same_or_newer doc, docid, file, docpath
      else
        write_file file, doc, docid
      end
      iso_queue.move_last docpath
    end

    def rewrite_with_same_or_newer(doc, docid, file, docpath)
      hash = YAML.load_file file
      item_hash = HashConverter.hash_to_bib hash
      bib = ::RelatonIsoBib::IsoBibliographicItem.new(**item_hash)
      if edition_greater?(doc, bib) || replace_substage98?(doc, bib)
        write_file file, doc, docid
      elsif @files.include?(file) && !edition_greater?(bib, doc)
        Util.warn "Duplicate file `#{file}` for `#{docid.id}` from #{url(docpath)}"
      end
    end

    def edition_greater?(doc, bib)
      doc.edition && bib.edition && doc.edition.content.to_i > bib.edition.content.to_i
    end

    def replace_substage98?(doc, bib) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      doc.edition&.content == bib.edition&.content &&
        (doc.status&.substage&.value != "98" || bib.status&.substage&.value == "98")
    end

    def write_file(file, doc, docid)
      @files << file
      index.add_or_update docid.to_h, file
      File.write file, serialize(doc), encoding: "UTF-8"
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
