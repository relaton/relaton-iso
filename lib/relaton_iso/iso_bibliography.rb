# frozen_string_literal: true

# require 'relaton_iso/iso_bibliographic_item'
require "relaton_iso/scrapper"
require "relaton_iso/hit_pages"
require "relaton_iec"

module RelatonIso
  # Class methods for search ISO standards.
  class IsoBibliography
    class << self
      # @param text [String]
      # @return [RelatonIso::HitPages]
      def search(text)
        HitPages.new text
      rescue Algolia::AlgoliaProtocolError
        warn "Could not access http://www.iso.org"
        []
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
        if year.nil?
          /^(?<code1>[^:]+):(?<year1>[^:]+)$/ =~ code
          unless code1.nil?
            code = code1
            year = year1
          end
        end
        code += "-1" if opts[:all_parts]
        return RelatonIec::IecBibliography.get(code, year, opts) if %r[^ISO/IEC DIR].match code

        ret = isobib_get1(code, year, opts)
        if ret.nil? && code =~ %r[^ISO\s]
          c = code.gsub "ISO", "ISO/IEC"
          warn "Attempting ISO/IEC retrieval"
          ret = isobib_get1(c, year, opts)
        end
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

      def fetch_pages(s, n)
        workers = RelatonBib::WorkersPool.new n
        workers.worker { |w| { i: w[:i], hit: w[:hit].fetch } }
        s.each_with_index { |hit, i| workers << { i: i, hit: hit } }
        workers.end
        workers.result.sort { |x, y| x[:i] <=> y[:i] }.map { |x| x[:hit] }
      end

      def isobib_search_filter(code)
        docidrx = %r{^(ISO|IEC)[^0-9]*\s[0-9-]+}
        corrigrx = %r{^(ISO|IEC)[^0-9]*\s[0-9-]+:[0-9]+/}
        warn "fetching #{code}..."
        result = search(code)
        result.each do |page|
          ret = page.select do |i|
            i.hit["title"] &&
              i.hit["title"].match(docidrx).to_s == code &&
              corrigrx !~ i.hit["title"]
          end
          return ret unless ret.empty?
        end
        []
      end

      # Sort through the results from RelatonIso, fetching them three at a time,
      # and return the first result that matches the code,
      # matches the year (if provided), and which # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error reporting
      def isobib_results_filter(result, year)
        missed_years = []
        result.each_slice(3) do |s| # ISO website only allows 3 connections
          fetch_pages(s, 3).each_with_index do |r, _i|
            next if r.nil?
            return { ret: r } if !year

            r.dates.select { |d| d.type == "published" }.each do |d|
              return { ret: r } if year.to_i == d.on.year

              missed_years << d.on.year
            end
          end
        end
        { years: missed_years }
      end

      def isobib_get1(code, year, _opts)
        # return iev(code) if /^IEC 60050-/.match code
        result = isobib_search_filter(code) || return
        ret = isobib_results_filter(result, year)
        return ret[:ret] if ret[:ret]

        fetch_ref_err(code, year, ret[:years])
      end
    end
  end
end
