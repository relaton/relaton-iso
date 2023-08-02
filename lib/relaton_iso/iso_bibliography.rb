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

        hits, missed_years = isobib_search_filter(query_pubid, opts)
        # hits, = isobib_search_filter(query_pubid, opts, any_types_stages: true) if hits.empty?

        tip_ids = look_up_with_any_types_stages(hits, query_pubid, opts)
        # tip_ids += look_up_isoiec_prefix(hits, query_pubid, opts)

        # return only first one if not all_parts
        ret = if !opts[:all_parts] || hits.size == 1
                hits.any? && hits.first.fetch(opts[:lang])
              else
                hits.to_all_parts(opts[:lang])
              end

        return fetch_ref_err(query_pubid, missed_years, tip_ids) unless ret

        response_docid = ret.docidentifier.first.id.sub(" (all parts)", "")
        response_pubid = Pubid::Iso::Identifier.parse(response_docid)

        # if query_pubid.to_s == response_pubid.to_s
        #   Logger.warn "(\"#{query_pubid}\") Found exact match."
        # elsif matches_base?(query_pubid, response_pubid)
        #   Logger.warn "(\"#{query_pubid}\") Found (\"#{response_pubid}\")."
        # elsif matches_base?(query_pubid, response_pubid, any_types_stages: true)
        #   Logger.warn "(\"#{query_pubid}\") TIP: Found with different " \
        #               "type/stage, please amend to (\"#{response_pubid}\")."
        # else
        #   # when there are all parts
        Logger.warn "(\"#{query_pubid}\") Found (\"#{response_pubid}\")."
        # end

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
      # @return [Array<RelatonIso::HitCollection, Array<String>>] hits and missed years
      def filter_hits_by_year(hit_collection, year) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        missed_years = []
        return [hit_collection, missed_years] if year.nil?

        # filter by year
        hits = hit_collection.select do |hit|
          if (hit.pubid.base.nil? && hit.pubid.year.to_s == year.to_s) ||
              (!hit.pubid.base.nil? && hit.pubid.base.year.to_s == year.to_s) ||
              (!hit.pubid.base.nil? && hit.pubid.year.to_s == year.to_s)
            true
          elsif hit.pubid.year.nil? && hit.hit[:year].to_s == year
            hit.pubid.year = year
            true
          else
            missed_year = (hit.pubid.year || hit.hit[:year]).to_s
            if missed_year && !missed_year.empty? && !missed_years.include?(missed_year)
              missed_years << missed_year
            end
            false
          end
        end

        [hits, missed_years]
      end

      private

      # @param query_pubid [Pubid::Iso::Identifier] PubID with no results
      def fetch_ref_err(pubid, missed_years, tip_ids) # rubocop:disable Metrics/MethodLength
        Logger.warn "(\"#{pubid}\") Not found."

        if missed_years.any?
          Logger.warn "(\"#{pubid}\") TIP: No match for edition year #{pubid.year}, " \
                      "but matches exist for #{missed_years.join(', ')}."
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

        # unless %w(TS TR PAS Guide).include?(pubid.type)
        #   Logger.warn "(\"#{pubid}\") TIP: If the document is not an " \
        #               "International Standard, use its " \
        #               "deliverable type abbreviation (TS, TR, PAS, Guide)."
        # end

        nil
      end

      # @param pubid [Pubid::Iso::Identifier]
      # @param missed_years [Array<String>]
      # def warn_missing_years(pubid, missed_years)
      #   Logger.warn "(\"#{pubid}\") TIP: No match for edition year #{pubid.year}, " \
      #               "but matches exist for #{missed_years.uniq.join(', ')}."
      # end

      # Search for hits using ISO/IEC prefix.
      #
      # @param pubid [Pubid::Iso::Identifier] reference with ISO prefix
      # @param opts [Hash]
      # @return [Array<RelatonIso::Hit>]
      # def look_up_isoiec_prefix(hits, pubid, opts) # rubocop:disable Metrics/MethodLength
      #   found_ids = []
      #   unless hits.empty? && pubid.copublisher.nil? && pubid.publisher == "ISO"
      #     return found_ids
      #   end

      #   new_pubid = pubid.dup
      #   new_pubid.copublisher = "IEC"
      #   # Logger.warn "(\"#{old_pubid}\") Not found, trying with ISO/IEC prefix (\"#{pubid}\")..."
      #   resp_isoiec, = isobib_search_filter(new_pubid, opts)

      #   # if resp_isoiec[:hits].empty?
      #   #   Logger.warn "(\"#{pubid}\") Not found. "
      #   #   return nil
      #   # end

      #   # Logger.warn "(\"#{pubid}\") TIP: Found with ISO/IEC prefix, please amend to (\"#{pubid}\")."
      #   found_ids << new_pubid if resp_isoiec.any?
      #   found_ids
      # end

      def look_up_with_any_types_stages(hits, pubid, opts) # rubocop:disable Metrics/MethodLength
        found_ids = []
        return found_ids unless !hits.from_gh && hits.empty? && pubid.copublisher.nil?

        # ref = typed_ref.sub(/^ISO\/\w+/, "ISO")
        # pubid = Pubid::Iso::Identifier.parse(ref)
        # Logger.warn "(\"#{typed_ref}\") Not found, trying without type (\"#{pubid}\")..."
        resp, = isobib_search_filter(pubid, opts, any_types_stages: true)
        # if resp_without_type[:hits].empty?
        #   Logger.warn "(\"#{pubid}\") Not found."
        #   return nil
        # end
        resp.map &:pubid
        # Logger.warn "(\"#{pubid}\") TIP: Found without type, please use reference (\"#{pubid}\")."
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
        # missed_years = []

        # fetch hits collection
        query_pubid_without_year = query_pubid.dup
        # remove year for query
        query_pubid_without_year.year = nil
        hit_collection = search(query_pubid_without_year.to_s)

        # filter only matching hits
        filter_hits hit_collection, query_pubid, opts[:all_parts], any_types_stages
        # return res unless res[:hits].empty?

        # missed_years += res[:missed_years]

        # lookup for documents with stages when no match without stage
        # filter_hits hit_collection, query_pubid, all_parts: opts[:all_parts], any_types_stages: true
        # return res unless res[:hits].empty?

        # missed_years += res[:missed_years]

        # if missed_years.any?
        #   warn_missing_years(query_pubid, missed_years)
        # end

        # res
      end

      # @param hits [RelatonIso::HitCollection]
      # @param query_pubid [Pubid::Iso::Identifier]
      # @param all_parts [Boolean]
      # @param any_stypes_tages [Boolean]
      # @return [Array<RelatonIso::HitCollection, Array<String>>] hits and missed years
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
