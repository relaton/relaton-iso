# frozen_string_literal: true

# require 'relaton_iso/iso_bibliographic_item'
require "relaton_iso/scrapper"
require "relaton_iso/hit_collection"
# require "relaton_iec"

module RelatonIso
  # Class methods for search ISO standards.
  class IsoBibliography
    class << self
      # @param text [String]
      # @return [RelatonIso::HitCollection]
      def search(text)
        HitCollection.new text.gsub("\u2013", "-")
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
        query_pubid.year = year if year
        query_pubid.part = nil if opts[:all_parts]
        Logger.warn "(\"#{query_pubid}\") Fetching from ISO..."

        hits, missed_year_ids = isobib_search_filter(query_pubid, opts)
        tip_ids = look_up_with_any_types_stages(hits, query_pubid, opts)

        ret = if !opts[:all_parts] || hits.size == 1
                hits.any? && hits.first.fetch(opts[:lang])
              else
                hits.to_all_parts(opts[:lang])
              end

        return fetch_ref_err(query_pubid, missed_year_ids, tip_ids) unless ret

        response_docid = ret.docidentifier.first.id.sub(" (all parts)", "")
        response_pubid = Pubid::Iso::Identifier.parse(response_docid)

        Logger.warn "(\"#{query_pubid}\") Found (\"#{response_pubid}\")."

        get_all = (
          (query_pubid.year && opts[:keep_year].nil?) ||
          opts[:keep_year] ||
          opts[:all_parts]
        )
        return ret if get_all

        ret.to_most_recent_reference
      rescue Pubid::Core::Errors::ParseError
        Logger.warn "(\"#{code}\") is not recognized as a standards identifier."
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
        Logger.warn "(\"#{pubid}\") Not found."

        if missed_year_ids.any?
          ids = missed_year_ids.map { |i| "\"#{i}\"" }.join(", ")
          Logger.warn "(\"#{pubid}\") TIP: No match for edition year " \
                      "#{pubid.year}, but matches exist for #{ids}."
        end

        if tip_ids.any?
          ids = tip_ids.map { |i| "\"#{i}\"" }.join(", ")
          Logger.warn "(\"#{pubid}\") TIP: Matches exist for #{ids}."
        end

        if pubid.part
          Logger.warn "(\"#{pubid}\") TIP: If it cannot be found, " \
                      "the document may no longer be published in parts."
        else
          Logger.warn "(\"#{pubid}\") TIP: If you wish to cite " \
                      "all document parts for the reference, use " \
                      "(\"#{pubid.to_s(format: :ref_undated)} (all parts)\")."
        end

        nil
      end

      def look_up_with_any_types_stages(hits, pubid, opts) # rubocop:disable Metrics/MethodLength
        found_ids = []
        return found_ids unless !hits.from_gh && hits.empty? && pubid.copublisher.nil?

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
      def isobib_search_filter(query_pubid, opts, any_types_stages: false) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        query_pubid_without_year = query_pubid.dup
        # remove year for query
        query_pubid_without_year.year = nil
        hit_collection = search(query_pubid_without_year.to_s)

        # filter only matching hits
        filter_hits hit_collection, query_pubid, opts[:all_parts], any_types_stages
      end

      #
      # Filter hits by query_pubid.
      #
      # @param hit_collection [RelatonIso::HitCollection]
      # @param query_pubid [Pubid::Iso::Identifier]
      # @param all_parts [Boolean]
      # @param any_stypes_tages [Boolean]
      #
      # @return [Array<RelatonIso::HitCollection, Array<String>>] hits and missed year IDs
      #
      def filter_hits(hit_collection, query_pubid, all_parts, any_stypes_tages) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        # filter out
        result = hit_collection.select do |i|
          hit_pubid = i.pubid
          matches_base?(query_pubid, hit_pubid, any_types_stages: any_stypes_tages) &&
            matches_parts?(query_pubid, hit_pubid, all_parts: all_parts) &&
            query_pubid.corrigendums == hit_pubid.corrigendums &&
            query_pubid.amendments == hit_pubid.amendments
        end

        filter_hits_by_year(result, query_pubid.year)
      end
    end
  end
end
