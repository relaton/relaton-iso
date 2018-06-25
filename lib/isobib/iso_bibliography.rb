# frozen_string_literal: true

# require 'isobib/iso_bibliographic_item'
require 'isobib/scrapper'
require 'isobib/hit_pages'

module Isobib
  # Class methods for search ISO standards.
  class IsoBibliography
    class << self
      # @param text [String]
      # @return [Isobib::HitPages]
      def search(text)
        HitPages.new text
      end

      # @param text [String]
      # @return [Array<IsoBibliographicItem>]
      def search_and_fetch(text)
        Scrapper.get(text)
      end

      # @param code [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @param year [String] the year the standard was published (optional)
      # @param opts [Hash] options; restricted to :all_parts if all-parts reference is required
      # @return [String] Relaton XML serialisation of reference
      def isobib_get(code, year, opts)
        return iev.to_xml if code.casecmp? "IEV"
        code += "-1" if opts[:all_parts]
        ret = isobib_get1(code, year, opts)
        return nil if ret.nil?
        ret.to_most_recent_reference if !year
        ret.to_all_parts if opts[:all_parts]
        ret.to_xml
      end

      private

      def fetch_ref_err(code, year, missed_years)
        id = year ? "#{code}:#{year}" : code
        warn "WARNING: no match found on the ISO website for #{id}. "\
          "The code must be exactly like it is on the website."
        warn "(There was no match for #{year}, though there were matches "\
          "found for #{missed_years.join(', ')}.)" unless missed_years.empty?
        if /\d-\d/.match? code
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
        workers = WorkersPool.new n
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
              !corrigrx.match?(i.hit["title"])
          end
          return ret unless ret.empty?
        end
        []
      end


      def iev
        Nokogiri::XML.fragment(<<~"END")
          <bibitem type="international-standard" id="IEV">
  <title format="text/plain" language="en" script="Latn">Electropedia: 
  The World's Online Electrotechnical Vocabulary</title>
  <source type="src">http://www.electropedia.org</source>
  <docidentifier>IEV</docidentifier>
  <date type="published"> <on>#{Date.today.year}</on> </date>
  <contributor>
    <role type="publisher"/>
    <organization>
      <name>International Electrotechnical Commission</name>
      <abbreviation>IEC</abbreviation>
      <uri>www.iec.ch</uri>
    </organization>
  </contributor>
  <language>en</language> <language>fr</language>
  <script>Latn</script>
  <copyright>
    <from>#{Date.today.year}</from>
    <owner>
      <organization>
      <name>International Electrotechnical Commission</name>
      <abbreviation>IEC</abbreviation>
      <uri>www.iec.ch</uri>
      </organization>
    </owner>
  </copyright>
  <relation type="updates">
    <bibitem>
      <formattedref>IEC 60050</formattedref>
    </bibitem>
  </relation>
</bibitem>
        END
      end


      # Sort through the results from Isobib, fetching them three at a time,
      # and return the first result that matches the code,
      # matches the year (if provided), and which # has a title (amendments do not).
      # Only expects the first page of results to be populated.
      # Does not match corrigenda etc (e.g. ISO 3166-1:2006/Cor 1:2007)
      # If no match, returns any years which caused mismatch, for error reporting
      def isobib_results_filter(result, year)
        missed_years = []
        result.each_slice(3) do |s| # ISO website only allows 3 connections
          fetch_pages(s, 3).each_with_index do |r, i|
            return { ret: r } if !year
            r.dates.select { |d| d.type == "published" }.each do |d|
              return { ret: r } if year.to_i == d.on.year
              missed_years << d.on.year
            end
          end
        end
        { years: missed_years }
      end

      def isobib_get1(code, year, opts)
        return iev if code.casecmp? "IEV"
        result = isobib_search_filter(code) or return nil
        ret = isobib_results_filter(result, year)
        return ret[:ret] if ret[:ret]
        fetch_ref_err(code, year, ret[:years])
      end
    end
  end
end
