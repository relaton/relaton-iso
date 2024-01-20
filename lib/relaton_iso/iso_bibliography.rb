# frozen_string_literal: true

# require 'relaton_iso/iso_bibliographic_item'
require "relaton_iso/scrapper"
require "relaton_iso/hit_collection"
# require "relaton_iec"

module RelatonIso
  # Class methods for search ISO standards.
  class IsoBibliography
    class << self
      # @param text [Pubid::Iso::Identifier, String]
      # @return [RelatonIso::HitCollection]
      def search(pubid, opts = {})
        pubid = Pubid::Iso::Identifier.parse(pubid) if pubid.is_a? String
        HitCollection.new(pubid).fetch(opts)
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET,
             EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
             Net::ProtocolError, OpenSSL::SSL::SSLError, Errno::ETIMEDOUT,
             Algolia::AlgoliaUnreachableHostError => e
        raise RelatonBib::RequestError, e.message
      end

      # @param ref [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @param year [String, NilClass] the year the standard was published
      # @param opts [Hash] options; restricted to :all_parts if all-parts
      # @option opts [Boolean] :all_parts if all-parts reference is required
      # @option opts [Boolean] :keep_year if undated reference should return
      #   actual reference with year
      #
      # @return [RelatonIsoBib::IsoBibliographicItem] Relaton XML serialisation of reference
      def get(ref, year = nil, opts = {}) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/AbcSize
        code = ref.gsub("\u2013", "-")

        # parse "all parts" request
        code.sub! " (all parts)", ""
        opts[:all_parts] ||= $~ && opts[:all_parts].nil?

        query_pubid = Pubid::Iso::Identifier.parse(code)
        query_pubid.root.year = year.to_i if year&.respond_to?(:to_i)
        # query_pubid.root.part = nil if opts[:all_parts]
        Util.warn "(#{query_pubid}) Fetching from iso.org ..."

        hits, missed_year_ids = isobib_search_filter(query_pubid, opts)
        tip_ids = look_up_with_any_types_stages(hits, ref, opts)
        ret = hits.fetch_doc(opts)
        return fetch_ref_err(query_pubid, missed_year_ids, tip_ids) unless ret

        response_pubid = ret.docidentifier.first.id # .sub(" (all parts)", "")
        # response_pubid = Pubid::Iso::Identifier.parse(response_docid)

        Util.warn "(#{query_pubid}) Found: `#{response_pubid}`"

        get_all = (query_pubid.year && opts[:keep_year].nil?) || opts[:keep_year] || opts[:all_parts]

        return ret if get_all

        ret.to_most_recent_reference
      rescue Pubid::Core::Errors::ParseError
        Util.warn "(#{code}) Is not recognized as a standards identifier."
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
      def matches_base?(query_pubid, pubid, any_types_stages: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics?PerceivedComplexity
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
        hits = hit_collection.select do |hit|
          hit.pubid.year ||= hit.hit[:year]
          next true if check_year(year, hit)

          missed_year_ids << hit.pubid.to_s if hit.pubid.year
          false
        end

        [hits, missed_year_ids]
      end

      private

      def check_year(year, hit) # rubocop:disable Metrics/AbcSize
        (hit.pubid.base.nil? && hit.pubid.year.to_s == year.to_s) ||
          (!hit.pubid.base.nil? && hit.pubid.base.year.to_s == year.to_s) ||
          (!hit.pubid.base.nil? && hit.pubid.year.to_s == year.to_s)
      end

      # @param pubid [Pubid::Iso::Identifier] PubID with no results
      def fetch_ref_err(pubid, missed_year_ids, tip_ids) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        Util.warn "(#{pubid}) Not found."

        if missed_year_ids.any?
          ids = missed_year_ids.map { |i| "`#{i}`" }.join(", ")
          Util.warn "(#{pubid}) TIP: No match for edition year " \
                    "#{pubid.year}, but matches exist for #{ids}."
        end

        if tip_ids.any?
          ids = tip_ids.map { |i| "`#{i}`" }.join(", ")
          Util.warn "(#{pubid}) TIP: Matches exist for #{ids}."
        end

        if pubid.part
          Util.warn "(#{pubid}) TIP: If it cannot be found, " \
                    "the document may no longer be published in parts."
        else
          Util.warn "(#{pubid}) TIP: If you wish to cite " \
                    "all document parts for the reference, use " \
                    "`#{pubid.to_s(format: :ref_undated)} (all parts)`."
        end

        nil
      end

      def look_up_with_any_types_stages(hits, ref, opts)
        found_ids = []
        return found_ids if hits.from_gh || hits.any? || !ref.match?(/^ISO[\/\s][A-Z]/)

        ref_no_type_stage = ref.sub(/^ISO[\/\s][A-Z]+/, "ISO")
        pubid = Pubid::Iso::Identifier.parse(ref_no_type_stage)
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
        filter_hits hit_collection, query_pubid, opts[:all_parts], any_types_stages
      end

      #
      # Filter hits by query_pubid.
      #
      # @param hit_collection [RelatonIso::HitCollection]
      # @param query_pubid [Pubid::Iso::Identifier]
      # @param all_parts [Boolean]
      # @param any_stypes_stages [Boolean]
      #
      # @return [Array<RelatonIso::HitCollection, Array<String>>] hits and missed year IDs
      #
      def filter_hits(hit_collection, query_pubid, all_parts, any_stypes_stages) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        # filter out
        excludes = [:year]
        excludes += %i[stage type] if any_stypes_stages
        excludes << :part if all_parts
        result = hit_collection.select do |i|
          if i.pubid.is_a? String then i.pubid == query_pubid.to_s
          else
            i.pubid.exclude(*excludes) == query_pubid.exclude(*excludes) && !(all_parts && i.pubid.part.nil?)
          end
        end

        filter_hits_by_year(result, query_pubid.year)
      end
    end
  end
end
