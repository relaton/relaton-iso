# frozen_string_literal: true

require_relative "hit"

module Relaton
  module Iso
    # Page of hit collection.
    class HitCollection < Relaton::Core::HitCollection
      INDEXFILE = "index-v1"
      ENDPOINT = "https://raw.githubusercontent.com/relaton/relaton-data-iso/main/"

      def opts
        @opts ||= {}
      end

      def ref_pubid_no_year
        @ref_pubid_no_year ||= ref.base ? ref.dup.tap { |r| r.base = r.base.exclude(:year) } : ref.exclude(:year)
      end

      def ref_pubid_excluded
        @ref_pubid_excluded ||= ref_pubid_no_year.exclude(*excludings)
      end

      #
      # Find all the entries that match the given reference.
      #
      # @return [Array<Relaton::Iso::Hit>] hits
      #
      def find
        @array = index.search do |row|
          row[:id].is_a?(Hash) ? pubid_match?(row[:id]) : ref.to_s == row[:id]
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
        ::Pubid::Iso::Identifier.create(**id)
      rescue StandardError => e
        Util.warn e.message, key: ref.to_s
      end

      def excludings
        return @excludings if defined? @excludings

        excl_parts = %i[year]
        excl_parts << :part if ref.root.part.nil? || opts[:all_parts]
        if ref.stage.nil? || opts[:all_parts]
          excl_parts << :stage
          excl_parts << :iteration
        end
        # excl_parts << :edition if ref.root.edition.nil? || all_parts
        @escludings = excl_parts
      end

      def index
        @index ||= Relaton::Index.find_or_create :iso, url: "#{ENDPOINT}#{INDEXFILE}.zip", file: "#{INDEXFILE}.yaml"
      end

      def fetch_doc(options)
        @excludeingds = nil if options != opts
        @opts = options

        if !opts[:all_parts] || size == 1
          any? && first.fetch(opts[:lang])
        else
          to_all_parts(opts[:lang])
        end
      end

      # @param lang [String, nil]
      # @return [RelatonIsoBib::IsoBibliographicItem, nil]
      def to_all_parts(lang = nil) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
        hit = @array.select { |h| h.pubid.part }.min_by { |h| h.pubid.part.to_i }
        return @array.first&.fetch(lang) unless hit

        bibitem = hit.fetch(lang)
        all_parts_item = bibitem.to_all_parts
        @array.reject { |h| h.pubid.part == hit.pubid.part }.each do |hi|
          all_parts_item.relation << create_relation(hi)
        end
        all_parts_item
      end

      def create_relation(hit)
        pubid = Pubid.new hit.pubid
        docid = Docidentifier.new(content: pubid, type: "ISO", primary: true)
        isobib = ItemData.new(formattedref: hit.pubid.to_s, docidentifier: [docid])
        Relation.new(type: "instanceOf", bibitem: isobib)
      end
    end
  end
end
