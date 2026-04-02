# frozen_string_literal: true

require_relative "hit"

module Relaton
  module Iso
    # Page of hit collection.
    class HitCollection < Relaton::Core::HitCollection
      ENDPOINT = "https://raw.githubusercontent.com/relaton/relaton-data-iso/data-v2/"

      def opts
        @opts ||= {}
      end

      def ref_pubid_no_year
        @ref_pubid_no_year ||= ref.base ? ref.dup.tap { |r| r.base = r.base.exclude(:year) } : ref.exclude(:year)
      end

      def ref_pubid_excluded
        return @ref_pubid_excluded if defined? @ref_pubid_excluded

        ref_excludings = excludings.dup
        ref_excludings << :all_parts
        @ref_pubid_excluded ||= ref_pubid_no_year.exclude(*ref_excludings)
      end

      #
      # Find all the entries that match the given reference.
      #
      # @return [Array<Relaton::Iso::Hit>] hits
      #
      def find # rubocop:disable Metrics/AbcSize
        @array = index.search do |row|
          row[:id].is_a?(Hash) || row[:id].is_a?(::Pubid::Core::Identifier::Base) ? pubid_match?(row[:id]) : ref.to_s(with_prf: true) == row[:id]
        end.map { |row| Hit.new row, self }
          .sort_by! { |h| h.pubid.to_s }
          .reverse!
        self
      end

      def pubid_match?(id)
        pubid = create_pubid(id)
        return false unless pubid

        # pubid.base = pubid.base.exclude(:year, :edition) if pubid.base
        dir_excludings = excludings.dup
        dir_excludings << :edition unless pubid.typed_stage_abbrev == "DIR"
        exclude_id_attrs(pubid, *dir_excludings) == ref_pubid_excluded
      end

      def create_pubid(id)
        return id if id.is_a?(::Pubid::Core::Identifier::Base)

        ::Pubid::Iso::Identifier.create(**id)
      rescue StandardError => e
        Util.warn e.message, key: ref.to_s
      end

      def exclude_id_attrs(pubid, *attrs)
        xid = pubid.exclude(*attrs)
        curr = xid
        while curr.base
          curr.base = curr.base.exclude(*attrs)
          curr = curr.base
        end
        xid
      end

      def excludings # rubocop:disable Metrics/AbcSize
        return @excludings if defined? @excludings

        excl_attrs = %i[year]
        excl_attrs << :part if ref.root.part.nil? || ref.root.all_parts
        if ref.stage.nil? || ref.root.all_parts
          excl_attrs << :stage
          excl_attrs << :iteration
        end
        # excl_parts << :edition if ref.root.edition.nil? || all_parts
        @excludings = excl_attrs
      end

      def index
        @index ||= Relaton::Index.find_or_create(
          :iso,
          url: "#{ENDPOINT}#{INDEXFILE}.zip",
          file: "#{INDEXFILE}.yaml",
          id_keys: %i[publisher number copublisher part year edition type stage
                      iteration joint_document tctype sctype wgtype tcnumber
                      scnumber wgnumber dirtype base supplements addendum
                      jtc_dir month amendments corrigendums language],
          pubid_class: ::Pubid::Iso::Identifier,
        )
      end

      def fetch_doc(options = {})
        @excludings = nil if options != opts
        @opts = options

        if !ref.root.all_parts || size == 1
          any? && first.item # (opts[:lang])
        else
          to_all_parts
        end
      end

      # @return [RelatonIsoBib::IsoBibliographicItem, nil]
      def to_all_parts # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
        parts = @array.select { |h| h.pubid.part }
        if opts[:publication_date_before] || opts[:publication_date_after]
          parts = parts.select { |h| Bibliography.send(:year_in_range?, (h.pubid.year || h.hit[:year]).to_i, opts) }
        end
        hit = parts.min_by { |h| h.pubid.part.to_i }
        return @array.first&.item unless hit

        bibitem = hit.item
        all_parts_item = bibitem.to_all_parts
        @array.reject { |h| h.pubid.part == hit.pubid.part }.each do |hi|
          all_parts_item.relation << create_relation(hi)
        end
        all_parts_item
      end

      def create_relation(hit)
        # pubid = Pubid.new hit.pubid
        docid = Docidentifier.new(content: hit.pubid, type: "ISO", primary: true)
        isobib = ItemData.new(formattedref: Bib::Formattedref.new(content: hit.pubid.to_s), docidentifier: [docid])
        Relation.new(type: "instanceOf", bibitem: isobib)
      end
    end
  end
end
