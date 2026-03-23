# frozen_string_literal: true

require "date"

# require 'relaton_iso/iso_bibliographic_item'
# require "relaton_iso/scrapper"
# require "relaton_iso/hit_collection"
# require "relaton_iec"

module Relaton
  module Iso
    # Methods for search ISO standards.
    module Bibliography
      extend self

      # @param text [Pubid::Iso::Identifier, String]
      # @return [RelatonIso::HitCollection]
      def search(pubid, opts = {})
        pubid = ::Pubid::Iso::Identifier.parse(pubid) if pubid.is_a? String
        HitCollection.new(pubid, opts).find
      rescue  SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET,
              EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
              Net::ProtocolError, OpenSSL::SSL::SSLError, Errno::ETIMEDOUT => e
        raise Relaton::RequestError, e.message
      end

      # @param ref [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @param year [String, NilClass] the year the standard was published
      # @param opts [Hash] options; restricted to :all_parts if all-parts
      # @option opts [Boolean] :all_parts if all-parts reference is required
      # @option opts [Boolean] :keep_year if undated reference should return
      #   actual reference with year
      #
      # @return [RelatonIsoBib::IsoBibliographicItem] Bibliographic item
      def get(ref, year = nil, opts = {}) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/AbcSize
        code = ref.gsub("\u2013", "-")

        # parse "all parts" request
        # code.sub! " (all parts)", ""
        # opts[:all_parts] ||= $~ && opts[:all_parts].nil?

        query_pubid = ::Pubid::Iso::Identifier.parse(code)
        query_pubid.root.year = year.to_i if year&.respond_to?(:to_i)
        query_pubid.root.all_parts ||= opts[:all_parts]
        Util.info "Fetching from Relaton repository ...", key: query_pubid.to_s

        hits, missed_year_ids = isobib_search_filter(query_pubid, opts)
        tip_ids = look_up_with_any_types_stages(hits, ref, opts)

        date_filter = opts[:publication_date_before] || opts[:publication_date_after]
        if date_filter && !query_pubid.root.all_parts
          ret = find_match_by_date(hits, query_pubid, opts)
        else
          ret = hits.fetch_doc(date_filter ? opts : {})
        end
        return fetch_ref_err(query_pubid, missed_year_ids, tip_ids) unless ret

        response_pubid = ret.docidentifier.find(&:primary) # .sub(" (all parts)", "")
        Util.info "Found: `#{response_pubid}`", key: query_pubid.to_s
        get_all = (query_pubid.root.year && opts[:keep_year].nil?) || opts[:keep_year] || opts[:all_parts] ||
          opts[:publication_date_before] || opts[:publication_date_after]
        if get_all
          filter_relations_by_date(ret, opts) if date_filter
          return ret
        end

        ret.to_most_recent_reference
      rescue ::Pubid::Core::Errors::ParseError
        Util.warn "Is not recognized as a standards identifier.", key: code
        nil
      end

      # @param query_pubid [Pubid::Iso::Identifier]
      # @param pubid [Pubid::Iso::Identifier]
      # @param all_parts [Boolean] match with any parts when true
      # @return [Boolean]
      def matches_parts?(query_pubid, pubid, all_parts: false)
        # match only with documents with part number
        return !pubid.part.nil? if all_parts

        query_pubid.part == pubid.part
      end

      #
      # Matches base of query_pubid and pubid.
      #
      # @param [Pubid::Iso::Identifier] query_pubid pubid to match
      # @param [Pubid::Iso::Identifier] pubid pubid to match
      # @param [Boolean] any_types_stages match with any types and stages
      #
      # @return [<Type>] <description>
      #
      def matches_base?(query_pubid, pubid, any_types_stages: false) # rubocop:disable Metrics?PerceivedComplexity
        return false unless pubid.respond_to?(:publisher)

        query_pubid.publisher == pubid.publisher &&
          query_pubid.number == pubid.number &&
          query_pubid.copublisher == pubid.copublisher &&
          (any_types_stages || query_pubid.stage == pubid.stage) &&
          (any_types_stages || query_pubid.is_a?(pubid.class))
      end

      # @param hit_collection [RelatonIso::HitCollection]
      # @param year [String]
      # @return [Array<RelatonIso::HitCollection, Array<String>>] hits and missed year IDs
      def filter_hits_by_year(hit_collection, year)
        missed_year_ids = Set.new
        return [hit_collection, missed_year_ids] if year.nil?

        # filter by year
        hit_collection.select! do |hit|
          hit.pubid.year ||= hit.hit[:year]
          next true if check_year(year, hit)

          missed_year_ids << hit.pubid.to_s if hit.pubid.year
          false
        end

        [hit_collection, missed_year_ids]
      end

      private

      # Filter out relations whose referenced document falls outside the date range.
      # @param item [Relaton::Iso::ItemData]
      # @param opts [Hash]
      def filter_relations_by_date(item, opts)
        return unless item.relation&.any?

        item.relation.reject! { |rel| relation_outside_date_range?(rel, opts) }
      end

      # Check if a relation's bibitem date falls outside the given date range.
      # @param rel [Relaton::Iso::Relation]
      # @param opts [Hash]
      # @return [Boolean]
      def relation_outside_date_range?(rel, opts)
        rel_date = relation_date(rel)
        return false unless rel_date

        return true if opts[:publication_date_before] && rel_date >= opts[:publication_date_before]
        return true if opts[:publication_date_after] && rel_date < opts[:publication_date_after]

        false
      end

      # Extract a Date from the relation's bibitem using circulated/published date or docidentifier year.
      # @param rel [Relaton::Iso::Relation]
      # @return [Date, nil]
      def relation_date(rel)
        bib = rel.bibitem
        date_entry = bib.date&.find { |d| d.type == "circulated" } ||
                     bib.date&.find { |d| d.type == "published" }
        return date_entry.at.to_date if date_entry&.at

        docid = bib.docidentifier&.find(&:primary)&.content || bib.formattedref
        return unless docid

        year = docid.to_s[/:(\d{4})/, 1]
        Date.new(year.to_i, 1, 1) if year
      end

      # Find the best match among hits using date filters.
      # @param hits [Relaton::Iso::HitCollection]
      # @param pubid [Pubid::Iso::Identifier]
      # @param opts [Hash]
      # @return [Relaton::Iso::ItemData, nil]
      def find_match_by_date(hits, pubid, opts) # rubocop:disable Metrics/AbcSize
        candidates = []
        hits.each { |h| candidates << h if year_in_range?(hit_year(h), opts) }
        candidates.sort_by { |h| -hit_year(h) }.each do |h|
          ret = fetch_and_check_date(h, pubid, opts)
          return ret if ret
        end
        nil
      end

      # Extract year from a hit as an integer.
      # @param hit [Relaton::Iso::Hit]
      # @return [Integer]
      def hit_year(hit)
        yr = hit.pubid&.year || hit.hit[:year]
        yr.to_i
      end

      # Check if a year falls within the date filter range.
      # @param year [Integer]
      # @param opts [Hash]
      # @return [Boolean]
      def year_in_range?(year, opts)
        return false if year.zero?

        if opts[:publication_date_before]
          return false if year > opts[:publication_date_before].year
        end
        if opts[:publication_date_after]
          return false if year < opts[:publication_date_after].year
        end
        true
      end

      # Check if the item's published date falls within the filter range.
      # @param item [Relaton::Iso::ItemData]
      # @param opts [Hash]
      # @return [Boolean]
      def publication_date_in_range?(item, opts)
        pub_date_entry = item.date.find { |d| d.type == "published" }
        return true unless pub_date_entry&.at

        pub_date = pub_date_entry.at.to_date
        return true unless pub_date

        if opts[:publication_date_before]
          return false if pub_date >= opts[:publication_date_before]
        end
        if opts[:publication_date_after]
          return false if pub_date < opts[:publication_date_after]
        end
        true
      end

      # Fetch the item for a hit and check if its publication date is in range.
      # @param hit [Relaton::Iso::Hit]
      # @param pubid [Pubid::Iso::Identifier]
      # @param opts [Hash]
      # @return [Relaton::Iso::ItemData, nil]
      def fetch_and_check_date(hit, pubid, opts)
        ret = hit.item
        if publication_date_in_range?(ret, opts)
          Util.info "Found: `#{ret.docidentifier.first.content}`", key: pubid.to_s
          ret
        end
      end

      def check_year(year, hit) # rubocop:disable Metrics/AbcSize
        (hit.pubid.base.nil? && hit.pubid.year.to_s == year.to_s) ||
          (!hit.pubid.base.nil? && hit.pubid.base.year.to_s == year.to_s) ||
          (!hit.pubid.base.nil? && hit.pubid.year.to_s == year.to_s)
      end

      # @param pubid [Pubid::Iso::Identifier] PubID with no results
      def fetch_ref_err(pubid, missed_year_ids, tip_ids) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        Util.info "Not found.", key: pubid.to_s

        if missed_year_ids.any?
          ids = missed_year_ids.map { |i| "`#{i}`" }.join(", ")
          Util.info "TIP: No match for edition year #{pubid.year}, but matches exist for #{ids}.", key: pubid.to_s
        end

        if tip_ids.any?
          ids = tip_ids.map { |i| "`#{i}`" }.join(", ")
          Util.info "TIP: Matches exist for #{ids}.", key: pubid.to_s
        end

        if pubid.part
          Util.info "TIP: If it cannot be found, the document may no longer be published in parts.", key: pubid.to_s
        else
          Util.info "TIP: If you wish to cite all document parts for the reference, " \
                    "use `#{pubid.to_s(format: :ref_undated)} (all parts)`.", key: pubid.to_s
        end

        nil
      end

      def look_up_with_any_types_stages(hits, ref, opts)
        return [] if hits.any? || !ref.match?(/^ISO[\/\s][A-Z]/)

        ref_no_type_stage = ref.sub(/^ISO[\/\s][A-Z]+/, "ISO")
        pubid = ::Pubid::Iso::Identifier.parse(ref_no_type_stage)
        resp, = isobib_search_filter(pubid, opts, any_types_stages: true)
        resp.map &:pubid
      end

      #
      # Search for hits. If no found then trying missed stages.
      #
      # @param query_pubid [Pubid::Iso::Identifier] reference without correction
      # @param opts [Hash]
      # @param any_types_stages [Boolean] match with any stages
      #
      # @return [Array<RelatonIso::HitCollection, Array<String>>] hits and missed years
      #
      def isobib_search_filter(query_pubid, opts, any_types_stages: false)
        hit_collection = search(query_pubid, opts)

        # filter only matching hits
        filter_hits hit_collection, query_pubid, any_types_stages
      end

      #
      # Filter hits by query_pubid.
      #
      # @param hit_collection [RelatonIso::HitCollection]
      # @param query_pubid [Pubid::Iso::Identifier]
      # @param all_parts [Boolean]
      # @param any_types_stages [Boolean]
      #
      # @return [Array<RelatonIso::HitCollection, Array<String>>] hits and missed year IDs
      #
      def filter_hits(hit_collection, query_pubid, any_types_stages) # rubocop:disable Metrics/AbcSize
        # filter out
        excludings = build_excludings(query_pubid.root.all_parts, any_types_stages)
        no_year_ref = hit_collection.ref_pubid_no_year.exclude(*excludings)
        hit_collection.select! do |i|
          pubid_match?(i.pubid, query_pubid, excludings, no_year_ref) &&
            !(query_pubid.root.all_parts && i.pubid.part.nil?)
        end

        filter_hits_by_year(hit_collection, query_pubid.root.year)
      end

      def build_excludings(all_parts, any_types_stages)
        excludings = %i[year edition all_parts]
        excludings += %i[type stage iteration] if any_types_stages
        excludings << :part if all_parts
        excludings
      end

      def pubid_match?(pubid, query_pubid, excludings, no_year_ref)
        if pubid.is_a? String then pubid == query_pubid.to_s
        else
          pubid = pubid.dup
          pubid.base = pubid.base.exclude(:year, :edition) if pubid.base
          pubid.exclude(*excludings) == no_year_ref
        end
      end
    end
  end
end
