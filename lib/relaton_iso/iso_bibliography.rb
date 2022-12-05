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
        HitCollection.new text.gsub(/\u2013/, "-")
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
        code = ref.gsub(/\u2013/, "-")

        # parse "all parts" request
        code.sub! " (all parts)", ""
        opts[:all_parts] ||= $~ && opts[:all_parts].nil?

        query_pubid = Pubid::Iso::Identifier.parse(code)
        query_pubid.year = year if year

        resp = isobib_search_filter(query_pubid, opts)

        # Try with ISO/IEC prefix if ISO not found
        if resp[:hits].empty? && query_pubid.copublisher.nil? &&
            query_pubid.publisher == "ISO"
          resp_isoiec = retry_isoiec_prefix(query_pubid, opts)
          resp = resp_isoiec unless resp_isoiec.nil?
        end

        # return only first one if not all_parts
        ret = if !opts[:all_parts] || resp[:hits].size == 1
                resp[:hits].any? && resp[:hits].first.fetch(opts[:lang])
              else
                resp[:hits].to_all_parts(opts[:lang])
              end

        return fetch_ref_err(query_pubid) unless ret

        # puts "xxxxx #{ret.docidentifier.first.id.inspect}"
        response_docid = ret.docidentifier.first.id.sub(" (all parts)", "")
        response_pubid = Pubid::Iso::Identifier.parse(response_docid)

        puts "xxxxx query_pubid(#{query_pubid}) response_pubid(#{response_pubid})"

        if query_pubid.to_s == response_pubid.to_s
          warn "[relaton-iso] (\"#{query_pubid}\") Found exact match."
        elsif matches_base?(query_pubid, response_pubid)
          warn "[relaton-iso] (\"#{query_pubid}\") " \
               "Found (\"#{response_pubid}\")."
        elsif matches_base?(query_pubid, response_pubid, any_types_stages: true)
          warn "[relaton-iso] (\"#{query_pubid}\") TIP: " \
               "Found with different type/stage, " \
               "please amend to (\"#{response_pubid}\")."
        else
          # when there are all parts
          warn "[relaton-iso] (\"#{query_pubid}\") Found (\"#{response_pubid}\")."
        end

        get_all = (
          (query_pubid.year && opts[:keep_year].nil?) ||
          opts[:keep_year] ||
          opts[:all_parts]
        )
        return ret if get_all

        ret.to_most_recent_reference

      rescue Pubid::Core::Errors::ParseError
        warn "[relaton-iso] (\"#{code}\") is not recognized as a standards identifier."
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

      def matches_base?(query_pubid, pubid, any_types_stages: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics?PerceivedComplexity
        query_pubid.publisher == pubid.publisher &&
          query_pubid.number == pubid.number &&
          query_pubid.copublisher == pubid.copublisher &&
          ((any_types_stages && query_pubid.stage.nil?) || query_pubid.stage == pubid.stage) &&
          ((any_types_stages && query_pubid.type.nil?) || query_pubid.type == pubid.type)
      end

      # @param hit_collection [RelatonIso::HitCollection]
      # @param year [String]
      # @return [RelatonIso::HitCollection]
      def filter_hits_by_year(hit_collection, year) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        missed_years = []
        return { hits: hit_collection, missed_years: missed_years } if year.nil?

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

        { hits: hits, missed_years: missed_years }
      end

      private

      # @param query_pubid [Pubid::Iso::Identifier] PubID with no results
      def fetch_ref_err(query_pubid) # rubocop:disable Metrics/MethodLength
        warn "[relaton-iso] (\"#{query_pubid}\") " \
             "Not found. " \
             "The identifier must be exactly as shown on the ISO website."

        if query_pubid.part
          warn "[relaton-iso] (\"#{query_pubid}\") TIP: " \
               "If it cannot be found, the document may no longer be published in parts."
        else
          warn "[relaton-iso] (\"#{query_pubid}\") TIP: " \
               "If you wish to cite all document parts for the reference, " \
               "use (\"#{query_pubid.to_s(with_date: false)} (all parts)\")."
        end

        unless %w(TS TR PAS Guide).include?(query_pubid.type)
          warn "[relaton-iso] (\"#{query_pubid}\") TIP: " \
               "If the document is not an International Standard, use its " \
               "deliverable type abbreviation (TS, TR, PAS, Guide)."
        end

        nil
      end

      # @param pubid [Pubid::Iso::Identifier]
      # @param missed_years [Array<String>]
      def warn_missing_years(pubid, missed_years)
        warn "[relaton-iso] (\"#{pubid}\") TIP: " \
             "No match for edition year #{pubid.year}, " \
             "but matches exist for #{missed_years.uniq.join(', ')}."
      end

      # Search for hits using ISO/IEC prefix.
      #
      # @param old_pubid [Pubid::Iso::Identifier] reference with ISO prefix
      # @param opts [Hash]
      # @return [Array<RelatonIso::Hit>]
      def retry_isoiec_prefix(old_pubid, opts) # rubocop:disable Metrics/MethodLength
        return nil unless old_pubid.copublisher.nil? && old_pubid.publisher == "ISO"

        pubid = old_pubid.dup
        pubid.copublisher = "IEC"
        warn "[relaton-iso] (\"#{old_pubid}\") Not found, trying with ISO/IEC prefix (\"#{pubid}\")..."
        resp_isoiec = isobib_search_filter(pubid, opts)

        if resp_isoiec[:hits].empty?
          warn "[relaton-iso] (\"#{pubid}\") Not found. "
          return nil
        end

        warn "[relaton-iso] (\"#{pubid}\") TIP: Found with ISO/IEC prefix, " \
             "please amend to (\"#{pubid}\")."

        resp_isoiec
      end

      # Search for hits. If no found then trying missed stages.
      #
      # @param query_pubid [Pubid::Iso::Identifier] reference without correction
      # @param opts [Hash]
      # @return [Array<RelatonIso::Hit>]
      def isobib_search_filter(query_pubid, opts) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        missed_years = []
        query_pubid.part = nil if opts[:all_parts]
        warn "[relaton-iso] (\"#{query_pubid}\") Fetching from ISO..."

        # fetch hits collection
        query_pubid_without_year = query_pubid.dup
        # remove year for query
        query_pubid_without_year.year = nil
        hit_collection = search(query_pubid_without_year.to_s(with_date: false))

        # filter only matching hits
        res = filter_hits hit_collection, query_pubid, all_parts: opts[:all_parts]
        return res unless res[:hits].empty?

        missed_years += res[:missed_years]

        # lookup for documents with stages when no match without stage
        res = filter_hits hit_collection, query_pubid,
                          all_parts: opts[:all_parts], any_types_stages: true
        return res unless res[:hits].empty?

        missed_years += res[:missed_years]

        if missed_years.any?
          warn_missing_years(query_pubid, missed_years)
        end

        res
      end

      # @param hits [RelatonIso::HitCollection]
      # @param query_pubid [Pubid::Iso::Identifier]
      # @param all_parts [Boolean]
      # @param any_stages [Boolean]
      # @return [RelatonIso::HitCollection]
      def filter_hits(hit_collection, query_pubid, all_parts: false, any_types_stages: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        # filter out
        result = hit_collection.select do |i|
          hit_pubid = i.pubid
          matches_base?(query_pubid, hit_pubid, any_types_stages: any_types_stages) &&
            matches_parts?(query_pubid, hit_pubid, all_parts: all_parts) &&
            query_pubid.corrigendums == hit_pubid.corrigendums &&
            query_pubid.amendments == hit_pubid.amendments
        end

        filter_hits_by_year(result, query_pubid.year)
      end
    end
  end
end
