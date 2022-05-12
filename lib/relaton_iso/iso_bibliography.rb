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
      # @return [String] Relaton XML serialisation of reference
      def get(ref, year = nil, opts = {}) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/AbcSize
        code = ref.gsub(/\u2013/, "-")
        # %r{\s(?<num>\d+)(?:-(?<part>[\d-]+))?(?::(?<year1>\d{4}))?} =~ code
        # TODO: extract with pubid-iso
        query_pubid = Pubid::Iso::Identifier.parse(ref)
        # year ||= publish_year ref
        year ||= query_pubid.year
        code.sub! " (all parts)", ""
        opts[:all_parts] ||= $~ && opts[:all_parts].nil?
        # opts[:keep_year] ||= opts[:keep_year].nil?
        # code.sub!("#{num}-#{part}", num) if opts[:all_parts] && part
        # if %r[^ISO/IEC DIR].match? code
        #   return RelatonIec::IecBibliography.get(code, year, opts)
        # end

        ret = isobib_get(query_pubid, year, opts)
        return nil if ret.nil?

        if (year && opts[:keep_year].nil?) || opts[:keep_year] || opts[:all_parts]
          ret
        else
          ret.to_most_recent_reference
        end
      end

      def extract_pubid_from(title)
        title.split.reverse.inject(title) do |acc, part|
          return Pubid::Iso::Identifier.parse(acc)
        rescue Pubid::Iso::Errors::ParseError
          # delete parts from the title until it's parseable
          acc.reverse.sub(part.reverse, "").reverse.strip
        end
      end

      def ref_components(ref)
        %r{
          ^(?<code>ISO(?:\s|/)[^-/:()]+\d+)
          (?:-(?<part>[\w-]+))?
          (?::(?<year>\d{4}))?
          (?:/(?<corr>\w+(?:\s\w+)?\s\d+)(?:(?<coryear>\d{4}))?)?
        }x =~ ref
        [code&.strip, part, year, corr, coryear]
      end

      def matches_amendment?(query_pubid, pubid)
        if query_pubid.amendment == pubid.amendment &&
          query_pubid.amendment_stage == pubid.amendment_stage
          return true
        end

        # when missing corrigendum year/number in query
        !query_pubid.amendment_number && query_pubid.amendment_version == pubid.amendment_version &&
          # corrigendum stage
          (!query_pubid.amendment_stage || query_pubid.amendment_stage == pubid.amendment_stage)
      end

      def matches_corrigendum?(query_pubid, pubid)
        # when matches full corrigendum part
        if query_pubid.corrigendum == pubid.corrigendum &&
          query_pubid.corrigendum_stage == pubid.corrigendum_stage
          return true
        end

        # when missing corrigendum year/number in query
        !query_pubid.corrigendum_number && query_pubid.corrigendum_version == pubid.corrigendum_version &&
          # corrigendum stage
          (!query_pubid.corrigendum_stage || query_pubid.corrigendum_stage == pubid.corrigendum_stage)
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

      def matches_base?(query_pubid, pubid)
        query_pubid.publisher == pubid.publisher &&
          query_pubid.number == pubid.number &&
          query_pubid.copublisher == pubid.copublisher &&
          query_pubid.type == pubid.type &&
          query_pubid.stage == pubid.stage
      end

      private

      # rubocop:disable Metrics/MethodLength

      def fetch_ref_err(query_pubid, year, missed_years)
        id = year ? "#{query_pubid}:#{year}" : query_pubid
        warn "[relaton-iso] WARNING: no match found online for #{id}. "\
             "The code must be exactly like it is on the standards website."
        unless missed_years.empty?
          warn "[relaton-iso] (There was no match for #{year}, though there "\
               "were matches found for #{missed_years.join(', ')}.)"
        end
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
        ref = remove_part query_pubid.to_s, opts[:all_parts]
        warn "[relaton-iso] (\"#{query_pubid}\") fetching..."
        # fetch hits collection
        result = search(ref)
        # filter only matching hits
        res = search_code result, query_pubid, opts
        return res unless res.empty?

        # try to match with any stage if no stage
        case code
        when %r{^\w+/[^/]+\s\d+} # code like ISO/IEC 123, ISO/IEC/IEE 123
          res = try_stages(result, opts) do |st|
            code.sub(%r{^(?<pref>[^\s]+\s)}) { "#{$~[:pref]}#{st} " }
          end
          return res unless res.empty?
        when %r{^\w+\s\d+} # code like ISO 123
          res = try_stages(result, opts) do |st|
            code.sub(%r{^(?<pref>\w+)}) { "#{$~[:pref]}/#{st}" }
          end
          return res unless res.empty?
        end

        if %r{^ISO\s}.match? code # try ISO/IEC if ISO not found
          warn "[relaton-iso] Attempting ISO/IEC retrieval"
          c = code.sub "ISO", "ISO/IEC"
          res = search_code result, c, opts
        end
        res
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      def remove_part(ref, all_parts)
        return ref unless all_parts

        ref.sub %r{(\S+\s\d+)[\d-]+}, '\1'
      end

      # @param result [RelatonIso::HitCollection]
      # @param opts [Hash]
      # @return [RelatonIso::HitCollection]
      def try_stages(result, opts)
        res = nil
        %w[NP WD CD DIS FDIS PRF IS AWI TR].each do |st| # try stages
          c = yield st
          res = search_code result, c, opts
          return res unless res.empty?
        end
        res
      end

      # @param result [RelatonIso::HitCollection]
      # @param query_pubid [Pubid::Iso::Identifier]
      # @param opts [Hash]
      # @return [RelatonIso::HitCollection]
      def search_code(result, query_pubid, opts) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        # filter out
        result.select do |i|
          hit_pubid = extract_pubid_from(i.hit[:title])
          matches_base?(query_pubid, hit_pubid) &&
            matches_parts?(query_pubid, hit_pubid, all_parts: opts[:all_parts]) &&
            matches_corrigendum?(query_pubid, hit_pubid) &&
            matches_amendment?(query_pubid, hit_pubid)
        end
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # Sort through the results from RelatonIso, fetching them three at a time,
      # and return the first result that matches the code, matches the year
      # (if provided), and which # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error
      # reporting
      def isobib_results_filter(result, year, opts)
        # only match with year in the query
        # or any year when year missing in query
        missed_years = []

        # filtering by year?
        hits = result.reduce!([]) do |hts, h|
          # TODO: extract with pubid-iso
          # TODO: extract pubid at Hit class?
          pubid = extract_pubid_from(h.hit[:title])
          # iyear = publish_year h.hit[:title]
          if !year || pubid.year == year
            hts << h
          else
            missed_years << pubid.year
            hts
          end
        end
        return { years: missed_years } unless hits.any?

        if !opts[:all_parts] || hits.size == 1
          return { ret: hits.first.fetch(opts[:lang]) }
        end

        { ret: hits.to_all_parts(opts[:lang]) }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # @param query_pubid [Pubid::Iso::Identifier]
      # @param year [String, NilClass]
      # @param opts [Hash]
      def isobib_get(query_pubid, year, opts)
        # return iev(code) if /^IEC 60050-/.match code
        result = isobib_search_filter(query_pubid, opts) || return
        ret = isobib_results_filter(result, year, opts)
        if ret[:ret]
          warn "[relaton-iso] (\"#{query_pubid}\") found #{ret[:ret].docidentifier.first.id}"
          ret[:ret]
        else
          fetch_ref_err(query_pubid, year, ret[:years])
        end
      end
    end
  end
end
