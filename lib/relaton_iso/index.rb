module RelatonIso
  # Index.
  class Index
    #
    # Initialise index. If file path is given, read index from file. If file is not
    # given, look for it in a `/home/USER/.relaton/iso` directory. If file
    # doesn't exist, or is outdated then fetch index from GitHub.
    #
    # @param [String, nil] file path to index file.
    #
    def initialize(file = nil)
      @file = file
    end

    #
    # Create index.
    #
    # @return [Array<Hash>] index
    #
    def index
      @index ||= read_index || read_from_user_dir || fetch_index
    end

    #
    # Add or update index entry.
    #
    # @param [RelatonIsoBib::IsoBibliographicItem] item document
    #
    # @return [void]
    #
    def <<(item)
      id = item.docidentifier.detect(&:primary).id
      row = self[id] || begin
        r = { id: id }
        index << r
        r
      end
      row[:title] = item.title.first.title.content
    end

    #
    # Fetch document from index by ID.
    #
    # @param [String] id document ID
    #
    # @return [Hash] index entry
    #
    def [](id)
      index.detect { |i| i[:id] == id }
    end

    #
    # Save index to file.
    #
    # @return [void]
    #
    def save
      serialize_and_save index
    end

    private

    #
    # Serialize index and save to file.
    #
    # @param [Array<Hash>] idx index
    #
    # @return [void]
    #
    def serialize_and_save(idx)
      File.open(@file, "w:UTF-8") do |f|
        f.puts "---"
        idx.each do |i|
          f.puts i.transform_keys(&:to_s).to_yaml.sub("---\n", "")
        end
      end
    end

    #
    # Read index from file. If file doesn't exist, create empty index.
    #
    # @return [Array<Hash>, nil] index
    #
    def read_index
      if @file && File.exist?(@file) then read_file
      elsif @file then []
      end
    end

    #
    # Read index from `/home/USER/.relaton/iso` or fetch it from GitHub,
    # if file doesn't exist, or is outdated.
    #
    # @return [Array<Hash>] index
    #
    def read_from_user_dir
      @file = File.join(Dir.home, "index.yml")
      read_file if File.exist?(@file) && !outdated?
    end

    def read_file
      yaml = File.read @file, encoding: "UTF-8"
      RelatonBib.parse_yaml yaml, [], symbolize_names: true
    end

    #
    # Check if index file is outdated.
    #
    # @return [Boolean] true if older than 24 hours
    #
    def outdated?
      (Time.now - File.mtime(@file)) / 3600 > 24
    end

    #
    # Fetch index from GitHub.
    #
    # @return [Array<Hash>] index
    #
    def fetch_index
      url = "https://raw.githubusercontent.com/relaton/relaton-data-iso/master/iso/index.zip"
      zip = Zip::InputStream.new URI(url).open
      yaml = zip.get_next_entry.get_input_stream.read
      idx = RelatonBib.parse_yaml yaml, [], symbolize_names: true
      serialize_and_save idx
      idx
    rescue OpenURI::HTTPError => e
      warn "[relaton-iso] WARNING: failed to fetch index: #{e.message}"
      []
    end
  end
end
