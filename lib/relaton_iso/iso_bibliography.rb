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
      # @return [RelatonIso::HitPages]
      def search(text)
        HitCollection.new text
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
        raise RelatonBib::RequestError, "Could not access http://www.iso.org"
      end

      # @param text [String]
      # @return [Array<RelatonIso::IsoBibliographicItem>]
      # def search_and_fetch(text)
      #   Scrapper.get(text)
      # end

      # @param code [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @param year [String] the year the standard was published (optional)
      # @param opts [Hash] options; restricted to :all_parts if all-parts reference is required,
      #   :keep_year if undated reference should return actual reference with year
      # @return [String] Relaton XML serialisation of reference
      def get(code, year, opts)
        %r{
          ^(?<code1>[^\s]+\s[^/]+) # match code
          /?
          (?<corr>(Amd|DAmd|CD Amd|Cor|CD Cor)\s\d+:?(\d{4})?(/Cor \d+:\d{4})?) # match correction
        }x =~ code
        code = code1 if code1

        if year.nil?
          /^(?<code1>[^\s]+\s[\d-]+):?(?<year1>\d{4})?/ =~ code
          unless code1.nil?
            code = code1
            year = year1
          end
        end
        code += "-1" if opts[:all_parts]
        return RelatonIec::IecBibliography.get(code, year, opts) if %r[^ISO/IEC DIR] =~ code

        ret = isobib_get1(code, year, corr)
        return nil if ret.nil?

        ret.to_most_recent_reference unless year || opts[:keep_year]
        ret.to_all_parts if opts[:all_parts]
        ret
      end

      private

      def fetch_ref_err(code, year, missed_years)
        id = year ? "#{code}:#{year}" : code
        warn "WARNING: no match found online for #{id}. "\
          "The code must be exactly like it is on the standards website."
        warn "(There was no match for #{year}, though there were matches "\
          "found for #{missed_years.join(', ')}.)" unless missed_years.empty?
        if /\d-\d/ =~ code
          warn "The provided document part may not exist, or the document "\
            "may no longer be published in parts."
        else
          warn "If you wanted to cite all document parts for the reference, "\
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
      def isobib_search_filter(code, corr)
        warn "fetching #{code}..."
        result = search(code)
        res = search_code result, code, corr
        return res unless res.empty?

        # try stages
        if %r{^\w+/[^/]+\s\d+} =~ code # code like ISO/IEC 123, ISO/IEC/IEE 123
          res = try_stages(result, corr) do |st|
            code.sub(%r{^(?<pref>[^\s]+\s)}) { "#{$~[:pref]}#{st} " }
          end
          return res unless res.empty?
        elsif %r{^\w+\s\d+} =~ code # code like ISO 123
          res = try_stages(result, corr) do |st|
            code.sub(%r{^(?<pref>\w+)}) { "#{$~[:pref]}/#{st}" }
          end
          return res unless res.empty?
        end

        if %r{^ISO\s} =~ code # try ISO/IEC if ISO not found
          warn "Attempting ISO/IEC retrieval"
          c = code.sub "ISO", "ISO/IEC"
          res = search_code result, c, corr
        end
        res
      end

      def try_stages(result, corr)
        %w[NP WD CD DIS FDIS PRF IS].each do |st| # try stages
          warn "Attempting #{st} stage retrieval"
          c = yield st
          res = search_code result, c, corr
          return res unless res.empty?
        end
        []
      end

      def search_code(result, code, corr)
        result.select do |i|
          i.hit["docRef"] =~ %r{^#{code}(?!-)} && (
              corr && %r{^#{code}[\w-]*(:\d{4})?/#{corr}} =~ i.hit["docRef"] ||
              %r{^#{code}[\w-]*(:\d{4})?/} !~ i.hit["docRef"] && !corr
            )
        end
      end

      # Sort through the results from RelatonIso, fetching them three at a time,
      # and return the first result that matches the code,
      # matches the year (if provided), and which # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error reporting
      def isobib_results_filter(result, year)
        missed_years = []
        result.each do |s|
          next if !year && s.hit["publicationStatus"] == "Withdrawn"
          return { ret: s.fetch } unless year

          %r{:(?<iyear>\d{4})} =~ s.hit["docRef"]
          return { ret: s.fetch } if iyear == year

          missed_years << iyear
        end
        { years: missed_years }
      end

      def isobib_get1(code, year, corr)
        # return iev(code) if /^IEC 60050-/.match code
        result = isobib_search_filter(code, corr) || return
        ret = isobib_results_filter(result, year)
        return ret[:ret] if ret[:ret]

        fetch_ref_err(code, year, ret[:years])
      end
    end
  end
end
