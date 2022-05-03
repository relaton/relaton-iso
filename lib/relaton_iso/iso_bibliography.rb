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
        year ||= publish_year ref
        code.sub! " (all parts)", ""
        opts[:all_parts] ||= $~ && opts[:all_parts].nil?
        # opts[:keep_year] ||= opts[:keep_year].nil?
        # code.sub!("#{num}-#{part}", num) if opts[:all_parts] && part
        # if %r[^ISO/IEC DIR].match? code
        #   return RelatonIec::IecBibliography.get(code, year, opts)
        # end

        ret = isobib_get(code, year, opts)
        return nil if ret.nil?

        if (year && opts[:keep_year].nil?) || opts[:keep_year] || opts[:all_parts]
          ret
        else
          ret.to_most_recent_reference
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

      private

      # rubocop:disable Metrics/MethodLength

      def fetch_ref_err(code, year, missed_years)
        id = year ? "#{code}:#{year}" : code
        warn "[relaton-iso] WARNING: no match found online for #{id}. "\
             "The code must be exactly like it is on the standards website."
        unless missed_years.empty?
          warn "[relaton-iso] (There was no match for #{year}, though there "\
               "were matches found for #{missed_years.join(', ')}.)"
        end
        if /\d-\d/.match? code
          warn "[relaton-iso] The provided document part may not exist, "\
               "or the document may no longer be published in parts."
        else
          warn "[relaton-iso] If you wanted to cite all document parts for "\
               "the reference, use \"#{code} (all parts)\".\nIf the document "\
               "is not a standard, use its document type abbreviation "\
               "(TS, TR, PAS, Guide)."
        end
        nil
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      # Search for hits. If no found then trying missed stages and ISO/IEC.
      #
      # @param code [String] reference without correction
      # @param opts [Hash]
      # @return [Array<RelatonIso::Hit>]
      def isobib_search_filter(code, opts)
        ref = remove_part code, opts[:all_parts]
        warn "[relaton-iso] (\"#{code}\") fetching..."
        result = search(ref)
        res = search_code result, code, opts
        return res unless res.empty?

        # try stages
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
      # @param code [String]
      # @param opts [Hash]
      # @return [RelatonIso::HitCollection]
      def search_code(result, code, opts) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        code1, part1, _, corr1, coryear1 = ref_components code
        result.select do |i|
          code2, part2, _, corr2, coryear2 = ref_components i.hit[:title]
          code1 == code2 && ((opts[:all_parts] && part2) || (!opts[:all_parts] && part1 == part2)) &&
            corr1 == corr2 && (!coryear1 || coryear1 == coryear2)
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
        missed_years = []
        hits = result.reduce!([]) do |hts, h|
          iyear = publish_year h.hit[:title]
          if !year || iyear == year
            hts << h
          else
            missed_years << iyear
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

      def publish_year(ref)
        %r{:(?<year>\d{4})(?!.*:\d{4})} =~ ref
        year
      end

      # @param code [String]
      # @param year [String, NilClass]
      # @param opts [Hash]
      def isobib_get(code, year, opts)
        # return iev(code) if /^IEC 60050-/.match code
        result = isobib_search_filter(code, opts) || return
        ret = isobib_results_filter(result, year, opts)
        if ret[:ret]
          warn "[relaton-iso] (\"#{code}\") found #{ret[:ret].docidentifier.first.id}"
          ret[:ret]
        else
          fetch_ref_err(code, year, ret[:years])
        end
      end
    end
  end
end
