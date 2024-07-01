# frozen_string_literal: true

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
      end.map { |row| Hit.new row, self }
        .sort_by! { |h| h.pubid.to_s }
        .reverse!
      self
    end

    def pubid_match?(id)
      pubid = create_pubid(id)
      return false unless pubid

      pubid.base = pubid.base.exclude(:year, :edition) if pubid.base
      dir_excludings = excludings.dup
      dir_excludings << :edition unless pubid.typed_stage_abbrev == "DIR"
      pubid.exclude(*dir_excludings) == ref_pubid_excluded
    end

    def create_pubid(id)
      Pubid::Iso::Identifier.create(**id)
    rescue StandardError => e
      Util.warn e.message, key: ref_pubid.to_s
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
  end
end
