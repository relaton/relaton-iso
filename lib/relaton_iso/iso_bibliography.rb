# frozen_string_literal: true

# require 'relaton_iso/iso_bibliographic_item'
require "relaton_iso/scrapper"
require "relaton_iso/hit_collection"
require "relaton_iec"

module RelatonIso
  # Class methods for search ISO standards.
  class IsoBibliography
    class << self
      # @param text [String]
      # @return [RelatonIso::HitCollection]
      def search(text)
        HitCollection.new text
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError,
             OpenSSL::SSL::SSLError, Errno::ETIMEDOUT
        raise RelatonBib::RequestError, "Could not access http://www.iso.org"
      end

      # @param ref [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @param year [String, NilClass] the year the standard was published
      # @param opts [Hash] options; restricted to :all_parts if all-parts
      #   reference is required, :keep_year if undated reference should
      #   return actual reference with year
      # @return [String] Relaton XML serialisation of reference
      def get(ref, year = nil, opts = {})
        opts[:ref] = ref

        %r{
          ^(?<code1>[^\s]+\s[^/]+) # match code
          /?
          (?<corr>(Amd|DAmd|(CD|WD|AWI|NP)\sAmd|Cor|CD\sCor|FDAmd|PRF\sAmd)\s\d+ # correction name
          :?(\d{4})?(/Cor\s\d+:\d{4})?) # match correction year
        }x =~ ref
        code = code1 || ref

        if year.nil?
          /^(?<code1>[^\s]+(\s\w+)?\s[\d-]+)(:(?<year1>\d{4}))?(?<code2>\s\w+)?/ =~ code
          unless code1.nil?
            code = code1 + code2.to_s
            year = year1
          end
        end
        opts[:all_parts] ||= code !~ %r{^[^\s]+\s\d+-\d+} && opts[:all_parts].nil? && code2.nil?
        return RelatonIec::IecBibliography.get(code, year, opts) if %r[^ISO/IEC DIR] =~ code

        ret = isobib_get1(code, year, corr, opts)
        return nil if ret.nil?

        if year || opts[:keep_year] || opts[:all_parts]
          ret
        else
          ret.to_most_recent_reference
        end
      end

      private

      def fetch_ref_err(code, year, missed_years)
        id = year ? "#{code}:#{year}" : code
        warn "[relaton-iso] WARNING: no match found online for #{id}. "\
          "The code must be exactly like it is on the standards website."
        warn "[relaton-iso] (There was no match for #{year}, though there were matches "\
          "found for #{missed_years.join(', ')}.)" unless missed_years.empty?
        if /\d-\d/ =~ code
          warn "[relaton-iso] The provided document part may not exist, or the document "\
            "may no longer be published in parts."
        else
          warn "[relaton-iso] If you wanted to cite all document parts for the reference, "\
            "use \"#{code} (all parts)\".\nIf the document is not a standard, "\
            "use its document type abbreviation (TS, TR, PAS, Guide)."
        end
        nil
      end

      # def fetch_pages(s, n)
      #   workers = RelatonBib::WorkersPool.new n
      #   workers.worker { |w| { i: w[:i], hit: w[:hit].fetch } }
      #   s.each_with_index { |hit, i| workers << { i: i, hit: hit } }
      #   workers.end
      #   workers.result.sort { |x, y| x[:i] <=> y[:i] }.map { |x| x[:hit] }
      # end

      # Search for hits. If no found then trying missed stages and ISO/IEC.
      #
      # @param code [String] reference without correction
      # @param corr [String] correction
      # @return [Array<RelatonIso::Hit>]
      def isobib_search_filter(code, corr, opts)
        warn "[relaton-iso] (\"#{opts[:ref]}\") fetching..."
        result = search(code)
        res = search_code result, code, corr, opts
        return res unless res.empty?

        # try stages
        if %r{^\w+/[^/]+\s\d+} =~ code # code like ISO/IEC 123, ISO/IEC/IEE 123
          res = try_stages(result, corr, opts) do |st|
            code.sub(%r{^(?<pref>[^\s]+\s)}) { "#{$~[:pref]}#{st} " }
          end
          return res unless res.empty?
        elsif %r{^\w+\s\d+} =~ code # code like ISO 123
          res = try_stages(result, corr, opts) do |st|
            code.sub(%r{^(?<pref>\w+)}) { "#{$~[:pref]}/#{st}" }
          end
          return res unless res.empty?
        end

        if %r{^ISO\s} =~ code # try ISO/IEC if ISO not found
          warn "[relaton-iso] Attempting ISO/IEC retrieval"
          c = code.sub "ISO", "ISO/IEC"
          res = search_code result, c, corr, opts
        end
        res
      end

      # @param result [RelatonIso::HitCollection]
      # @param corr [String] correction
      # @param opts [Hash]
      def try_stages(result, corr, opts)
        res = nil
        %w[NP WD CD DIS FDIS PRF IS AWI TR].each do |st| # try stages
          c = yield st
          res = search_code result, c, corr, opts
          return res unless res.empty?
        end
        res
      end

      def search_code(result, code, corr, opts)
        result.select do |i|
          (opts[:all_parts] || i.hit["docRef"] =~ %r{^#{code}(?!-)}) && (
              corr && %r{^#{code}[\w-]*(:\d{4})?/#{corr}} =~ i.hit["docRef"] ||
              !corr && %r{^#{code}[\w-]*(:\d{4})?/} !~ i.hit["docRef"]
            ) # && %r{^#{code}} =~ i.hit["docRef"]
        end
      end

      # Sort through the results from RelatonIso, fetching them three at a time,
      # and return the first result that matches the code,
      # matches the year (if provided), and which # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error reporting
      def isobib_results_filter(result, year, opts)
        missed_years = []
        hits = result.reduce!([]) do |hts, h|
          # if !year && h.hit["publicationStatus"] == "Withdrawn"
          #   hts
          if !year || %r{:(?<iyear>\d{4})} =~ h.hit["docRef"] && iyear == year
            hts << h
          else
            missed_years << iyear
            hts
          end
        end
        return { years: missed_years } unless hits.any?

        return { ret: hits.first.fetch(opts[:lang]) } if !opts[:all_parts] || hits.size == 1

        { ret: hits.to_all_parts(opts[:lang]) }
      end

      # @param code [String]
      # @param year [String, NilClass]
      # @param corr [String, NilClass]
      # @param opts [Hash]
      def isobib_get1(code, year, corr, opts)
        # return iev(code) if /^IEC 60050-/.match code
        result = isobib_search_filter(code, corr, opts) || return
        ret = isobib_results_filter(result, year, opts)
        if ret[:ret]
          warn "[relaton-iso] (\"#{opts[:ref]}\") found #{ret[:ret].docidentifier.first.id}"
          ret[:ret]
        else
          fetch_ref_err(code, year, ret[:years])
        end
      end
    end
  end
end
