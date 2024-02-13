# frozen_string_literal: true

require "algolia"
require "relaton_iso/hit"

module RelatonIso
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    INDEXFILE = "index-v1.yaml"
    ENDPOINT = "https://raw.githubusercontent.com/relaton/relaton-data-iso/main/"

    # @param text [Pubid::Iso::Identifier] reference to search
    def initialize(pubid, opts = {})
      super
      @opts = opts
    end

    # @return [Pubid::Iso::Identifier]
    alias ref_pubid text

    def ref_pubid_no_year
      @ref_pubid_no_year ||= ref_pubid.dup.tap { |r| r.base = r.base.exclude(:year) if r.base }
    end

    def ref_pubid_excluded
      @ref_pubid_excluded ||= ref_pubid_no_year.exclude(*excludings)
    end

    def fetch # rubocop:disable Metrics/AbcSize
      @array = index.search do |row|
        row[:id].is_a?(Hash) ? pubid_match?(row[:id]) : ref_pubid.to_s == row[:id]
      end.map { |row| Hit.new row, self }.sort_by! { |h| h.pubid.to_s }.reverse!
      self
    end

    def pubid_match?(id) # rubocop:disable Metrics/AbcSize
      pubid = Pubid::Iso::Identifier.create(**id)
      pubid.base = pubid.base.exclude(:year, :edition) if pubid.base
      dir_excludings = excludings.dup
      dir_excludings << :edition unless pubid.typed_stage_abbrev == "DIR"
      pubid.exclude(*dir_excludings) == ref_pubid_excluded
    rescue StandardError => e
      Util.warn "(#{ref_pubid}) WARNING: #{e.message}"
    end

    def excludings
      return @excludings if defined? @excludings

      excl_parts = %i[year]
      excl_parts << :part if ref_pubid.root.part.nil? || @opts[:all_parts]
      if ref_pubid.stage.nil? || @opts[:all_parts]
        excl_parts << :stage
        excl_parts << :iteration
      end
      # excl_parts << :edition if ref_pubid.root.edition.nil? || all_parts
      @escludings = excl_parts
    end

    def index
      @index ||= Relaton::Index.find_or_create :iso, url: "#{ENDPOINT}index-v1.zip", file: INDEXFILE
    end

    def fetch_doc
      if !@opts[:all_parts] || size == 1
        any? && first.fetch(@opts[:lang])
      else
        to_all_parts(@opts[:lang])
      end
    end

    # @param lang [String, nil]
    # @return [RelatonIsoBib::IsoBibliographicItem, nil]
    def to_all_parts(lang = nil) # rubocop:disable Metrics/AbcSize
      hit = @array.min_by { |h| h.pubid.part.to_i }
      return @array.first&.fetch lang unless hit

      bibitem = hit.fetch(lang)
      all_parts_item = bibitem.to_all_parts
      @array.reject { |h| h.pubid.part == hit.pubid.part }.each do |hi|
        all_parts_item.relation << create_relation(hi)
      end
      all_parts_item
    end

    def create_relation(hit)
      docid = DocumentIdentifier.new(id: hit.pubid, type: "ISO", primary: true)
      isobib = RelatonIsoBib::IsoBibliographicItem.new(
        formattedref: RelatonBib::FormattedRef.new(content: hit.pubid.to_s), docid: [docid],
      )
      RelatonBib::DocumentRelation.new(type: "instanceOf", bibitem: isobib)
    end

    # private

    #
    # Fetch document from GitHub repository
    #
    # @return [Array<RelatonIso::Hit]
    #
    # def fetch_github # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    #   ref = text.gsub(/[\s\/]/, "_").upcase
    #   url = "https://raw.githubusercontent.com/relaton/relaton-data-iso/main/data/#{ref}.yaml"
    #   resp = Net::HTTP.get_response URI(url)
    #   return [] unless resp.code == "200"

    #   hash = YAML.safe_load resp.body
    #   bib_hash = HashConverter.hash_to_bib hash
    #   bib_hash[:fetched] = Date.today.to_s
    #   bib = RelatonIsoBib::IsoBibliographicItem.new(**bib_hash)
    #   hit = Hit.new({ title: text }, self)
    #   hit.fetch = bib
    #   [hit]
    # end

    #
    # Fetch hits from iso.org
    #
    # @return [Array<RelatonIso::Hit>]
    #
    # def fetch_iso # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    #   config = Algolia::Search::Config.new(application_id: "JCL49WV5AR", api_key: "dd1b9e1ab383f4d4817d29cd5e96d3f0")
    #   client = Algolia::Search::Client.new config, logger: RelatonIso.configuration.logger
    #   index = client.init_index "all_en"
    #   resp = index.search text, hitsPerPage: 100, filters: "category:standard"

    #   resp[:hits].map { |h| Hit.new h, self }.sort! do |a, b|
    #     if a.sort_weight == b.sort_weight && b.hit[:year] = a.hit[:year]
    #       a.hit[:title] <=> b.hit[:title]
    #     elsif a.sort_weight == b.sort_weight
    #       b.hit[:year] - a.hit[:year]
    #     else
    #       a.sort_weight - b.sort_weight
    #     end
    #   end
    # end
  end
end
