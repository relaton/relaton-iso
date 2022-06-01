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
        # %r{\s(?<num>\d+)(?:-(?<part>[\d-]+))?(?::(?<year1>\d{4}))?} =~ code
        # TODO: extract with pubid-iso
        code.sub! " (all parts)", ""
        opts[:all_parts] ||= $~ && opts[:all_parts].nil?
        query_pubid = Pubid::Iso::Identifier.parse(code)
        query_pubid.year = year if year

        hits = isobib_search_filter(query_pubid, opts)

        # return only first one if not all_parts
        ret = if !opts[:all_parts] || hits.size == 1
                hits.any? && hits.first.fetch(opts[:lang])
              else
                hits.to_all_parts(opts[:lang])
              end

        if ret
          warn "[relaton-iso] (\"#{query_pubid}\") found #{ret.docidentifier.first.id}"
        else
          return fetch_ref_err(query_pubid, query_pubid.year)
        end

        if (query_pubid.year && opts[:keep_year].nil?) || opts[:keep_year] || opts[:all_parts]
          ret
        else
          ret.to_most_recent_reference
        end
      end

      # @param query_pubid [Pubid::Iso::Identifier]
      # @param pubid [Pubid::Iso::Identifier]
      # @param all_parts [Boolean] match with any parts when true
      # @return [Boolean]
      def matches_parts?(query_pubid, pubid, all_parts: false)
        if all_parts
          # match only with documents with part number
          !pubid.part.nil?
        else
          query_pubid.part == pubid.part
        end
      end

      def matches_base?(query_pubid, pubid, any_types_stages: false)
        query_pubid.publisher == pubid.publisher &&
          query_pubid.number == pubid.number &&
          query_pubid.copublisher == pubid.copublisher &&
          (any_types_stages && query_pubid.stage.nil? || query_pubid.stage == pubid.stage) &&
          (any_types_stages && query_pubid.type.nil? || query_pubid.type == pubid.type)
      end

      # @param hit_collection [RelatonIso::HitCollection]
      # @param year [String]
      # @return [RelatonIso::HitCollection]
      def filter_hits_by_year(hit_collection, year)
        missed_years = []

        # filter by year
        hits = hit_collection.select do |hit|
          if hit.pubid.year == year
            true
          else
            missed_years << hit.pubid.year
            false
          end
        end

        if hits.empty? && !missed_years.empty?
          warn "[relaton-iso] (There was no match for #{year}, though there "\
               "were matches found for #{missed_years.join(', ')}.)"
        end
        hits
      end

      private

      # rubocop:disable Metrics/MethodLength

      def fetch_ref_err(query_pubid, year)
        id = year ? "#{query_pubid}:#{year}" : query_pubid
        warn "[relaton-iso] WARNING: no match found online for #{id}. "\
             "The code must be exactly like it is on the standards website."
        if /\d-\d/.match? query_pubid.to_s
          warn "[relaton-iso] The provided document part may not exist, "\
               "or the document may no longer be published in parts."
        else
          warn "[relaton-iso] If you wanted to cite all document parts for "\
               "the reference, use \"#{query_pubid} (all parts)\".\nIf the document "\
               "is not a standard, use its document type abbreviation "\
               "(TS, TR, PAS, Guide)."
        end
        nil
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      # Search for hits. If no found then trying missed stages and ISO/IEC.
      #
      # @param query_pubid [Pubid::Iso::Identifier] reference without correction
      # @param opts [Hash]
      # @return [Array<RelatonIso::Hit>]
      def isobib_search_filter(query_pubid, opts)
        ref = remove_part query_pubid.to_s(with_date: false), opts[:all_parts]
        warn "[relaton-iso] (\"#{query_pubid}\") fetching..."
        # fetch hits collection
        hit_collection = search(ref)
        # filter only matching hits
        res = filter_hits hit_collection, query_pubid,
                          all_parts: opts[:all_parts]
        return res unless res.empty?

        res = filter_hits hit_collection, query_pubid,
                          all_parts: opts[:all_parts], any_types_stages: true
        return res unless res.empty?

        # TODO: do this at pubid-iso
        if query_pubid.publisher == "ISO" && query_pubid.copublisher.nil? # try ISO/IEC if ISO not found
          warn "[relaton-iso] Attempting ISO/IEC retrieval"
          query_pubid.copublisher = "IEC"
          res = filter_hits hit_collection, query_pubid, all_parts: opts[:all_parts]
        end
        res
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      def remove_part(ref, all_parts)
        return ref unless all_parts

        ref.sub %r{(\S+\s\d+)[\d-]+}, '\1'
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
            query_pubid.corrigendum == hit_pubid.corrigendum &&
            query_pubid.amendment == hit_pubid.amendment
        end

        query_pubid.year ? filter_hits_by_year(result, query_pubid.year) : result
      end
    end
  end
end
