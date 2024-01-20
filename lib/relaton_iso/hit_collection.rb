# frozen_string_literal: true

require "algolia"
require "relaton_iso/hit"

module RelatonIso
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    INDEXFILE = "index-v1.yaml"
    ENDPOINT = "https://raw.githubusercontent.com/relaton/relaton-data-iso/main/"

    # @return [Boolean] whether the search was performed on GitHub
    attr_reader :from_gh

    # @param text [Pubid::Iso::Identifier] reference to search
    def initialize(pubid)
      super
      @from_gh = pubid.to_s.match?(/^ISO[\s\/](?:TC\s184\/SC\s?4|IEC\sDIR\s(?:\d|IEC|JTC))/)
    end

    # @return [Pubid::Iso::Identifier]
    alias ref_pubid text

    def fetch(opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      # @array = from_gh ? fetch_github : fetch_iso
      excludings = [:year]
      excludings << :part if ref_pubid.part.nil? || opts[:all_parts]
      @array = index.search do |row|
        if row[:id].is_a? Hash
          begin
            pubid = Pubid::Iso::Identifier.create(**row[:id])
          rescue StandardError => e
            e
          end
          pubid.exclude(*excludings) == ref_pubid.exclude(*excludings)
        else
          ref_pubid.to_s == row[:id]
        end
      end.map { |row| Hit.new row, self }
      self
    end

    def index
      @index ||= Relaton::Index.find_or_create :iso, url: "#{ENDPOINT}index-v1.zip", file: INDEXFILE
    end

    def fetch_doc(opts)
      if !opts[:all_parts] || size == 1
        any? && first.fetch(opts[:lang])
      else
        to_all_parts(opts[:lang])
      end
    end

    # @param lang [String, nil]
    # @return [RelatonIsoBib::IsoBibliographicItem, nil]
    def to_all_parts(lang = nil) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      # parts = @array.reject { |h| h.hit["docPart"]&.empty? }
      hit = @array.min_by { |h| h.pubid.part.to_i }
      return @array.first&.fetch lang unless hit

      bibitem = hit.fetch(lang)
      all_parts_item = bibitem.to_all_parts
      @array.reject { |h| h.pubid.part == hit.pubid.part }.each do |hi|
        isobib = RelatonIsoBib::IsoBibliographicItem.new(
          formattedref: RelatonBib::FormattedRef.new(content: hi.pubid.to_s),
          docid: [DocumentIdentifier.new(id: hi.pubid, type: "ISO", primary: true)],
        )
        all_parts_item.relation << RelatonBib::DocumentRelation.new(
          type: "instanceOf", bibitem: isobib,
        )
      end
      all_parts_item
    end

    private

    #
    # Fetch document from GitHub repository
    #
    # @return [Array<RelatonIso::Hit]
    #
    def fetch_github # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      ref = text.gsub(/[\s\/]/, "_").upcase
      url = "https://raw.githubusercontent.com/relaton/relaton-data-iso/main/data/#{ref}.yaml"
      resp = Net::HTTP.get_response URI(url)
      return [] unless resp.code == "200"

      hash = YAML.safe_load resp.body
      bib_hash = HashConverter.hash_to_bib hash
      bib_hash[:fetched] = Date.today.to_s
      bib = RelatonIsoBib::IsoBibliographicItem.new(**bib_hash)
      hit = Hit.new({ title: text }, self)
      hit.fetch = bib
      [hit]
    end

    #
    # Fetch hits from iso.org
    #
    # @return [Array<RelatonIso::Hit>]
    #
    def fetch_iso # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      config = Algolia::Search::Config.new(application_id: "JCL49WV5AR", api_key: "dd1b9e1ab383f4d4817d29cd5e96d3f0")
      client = Algolia::Search::Client.new config, logger: RelatonIso.configuration.logger
      index = client.init_index "all_en"
      resp = index.search text, hitsPerPage: 100, filters: "category:standard"

      resp[:hits].map { |h| Hit.new h, self }.sort! do |a, b|
        if a.sort_weight == b.sort_weight && b.hit[:year] = a.hit[:year]
          a.hit[:title] <=> b.hit[:title]
        elsif a.sort_weight == b.sort_weight
          b.hit[:year] - a.hit[:year]
        else
          a.sort_weight - b.sort_weight
        end
      end
    end
  end
end
