# frozen_string_literal: true

require "relaton_iso_bib"
require "relaton_iso/hit"
require "nokogiri"
require "net/http"

module RelatonIso
  # Scrapper.
  module Scrapper # rubocop:disable Metrics/ModuleLength
    DOMAIN = "https://www.iso.org"

    TYPES = {
      "TS" => "technical-specification",
      "TR" => "technical-report",
      "PAS" => "publicly-available-specification",
      # "AWI" => "approvedWorkItem",
      # "CD" => "committeeDraft",
      # "FDIS" => "finalDraftInternationalStandard",
      # "NP" => "newProposal",
      # "DIS" => "draftInternationalStandard",
      # "WD" => "workingDraft",
      # "R" => "recommendation",
      "Guide" => "guide",
    }.freeze

    STGABBR = {
      "00" => "NWIP",
      "10" => "AWI",
      "20" => "WD",
      "30" => "CD",
      "40" => "DIS",
      "50" => "FDIS",
      "60" => { "00" => "PRF", "60" => "FINAL" },
    }.freeze

    PUBLISHERS = {
      "IEC" => { name: "International Electrotechnical Commission",
                 url: "www.iec.ch" },
      "ISO" => { name: "International Organization for Standardization",
                 url: "www.iso.org" },
      "IEEE" => { name: "Institute of Electrical and Electronics Engineers",
                  url: "www.ieee.org" },
      "SAE" => { name: "SAE International", url: "www.sae.org" },
      "CIE" => { name: " International Commission on Illumination",
                 url: "cie.co.at" },
      "ASME" => { name: "American Society of Mechanical Engineers",
                  url: "www.asme.org" },
    }.freeze

    class << self
      # Parse page.
      # @param hit_data [Hash]
      # @param lang [String, NilClass]
      # @return [Hash]
      def parse_page(hit_data, lang = nil) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        # path = "/contents/data/standard#{hit_data['splitPath']}/"\
        # "#{hit_data['csnumber']}.html"
        doc, url = get_page "#{hit_data[:path].sub '/sites/isoorg', ''}.html"

        # Fetch edition.
        edition = doc&.xpath("//strong[contains(text(), 'Edition')]/..")
          &.children&.last&.text&.match(/\d+/)&.to_s

        titles, abstract, langs = fetch_titles_abstract(doc, lang)

        RelatonIsoBib::IsoBibliographicItem.new(
          fetched: Date.today.to_s,
          docid: fetch_relaton_docids(
            Pubid::Iso::Identifier.parse(item_ref(doc)), edition, langs, stage_code(doc).to_f
          ),
          docnumber: fetch_docnumber(doc),
          edition: edition,
          language: langs.map { |l| l[:lang] },
          script: langs.map { |l| script(l[:lang]) }.uniq,
          title: titles,
          doctype: fetch_type(hit_data[:title]),
          docstatus: fetch_status(doc),
          ics: fetch_ics(doc),
          date: fetch_dates(doc, hit_data[:title]),
          contributor: fetch_contributors(hit_data[:title]),
          editorialgroup: fetch_workgroup(doc),
          abstract: abstract,
          copyright: fetch_copyright(doc),
          link: fetch_link(doc, url),
          relation: fetch_relations(doc),
          place: ["Geneva"],
          structuredidentifier: fetch_structuredidentifier(doc),
        )
      end

      # Fetch relaton docids.
      # @param pubid [Pubid::Iso::Identifier]
      # @param edition [String]
      # @param langs [Array<Hash>]
      # @param stage [Float]
      # @return [Array<RelatonBib::DocumentIdentifier>]
      def fetch_relaton_docids(pubid, edition, langs, stage)
        pubid.edition = edition
        pubid.language = langs.map { |k| k[:lang] }.join(",") if langs
        pubid.urn_stage = stage
        [
          RelatonBib::DocumentIdentifier.new(id: pubid.to_s, type: "ISO",
                                             primary: true),
          RelatonBib::DocumentIdentifier.new(id: pubid.urn.to_s, type: "URN"),
        ]
      end

      private

      # Fetch titles and abstracts.
      # @param doc [Nokigiri::HTML::Document]
      # @param lang [String, NilClass]
      # @return [Array<Array>]
      def fetch_titles_abstract(doc, lang) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        titles   = RelatonBib::TypedTitleStringCollection.new
        abstract = []
        langs = languages(doc, lang).reduce([]) do |s, l|
          # Don't need to get page for en. We already have it.
          d = l[:path] ? get_page(l[:path])[0] : doc
          unless d.at("//h5[@class='help-block']"\
                      "[.='недоступно на русском языке']")
            s << l
            titles += fetch_title(d, l[:lang])

            # Fetch abstracts.
            abstract_content = d.xpath(
              "//div[@itemprop='description']/p|//div[@itemprop='description']/ul/li",
            ).map do |a|
              a.name == "li" ? "- #{a.text}" : a.text
            end.reject(&:empty?).join("\n")
            unless abstract_content.empty?
              abstract << {
                content: abstract_content,
                language: l[:lang],
                script: script(l[:lang]),
                format: "text/plain",
              }
            end
          end
          s
        end
        [titles, abstract, langs]
      end

      # Returns available languages.
      # @param doc [Nokogiri::HTML::Document]
      # @pqrqm lang [String, NilClass]
      # @return [Array<Hash>]
      def languages(doc, lang)
        lgs = [{ lang: "en" }]
        doc.css("li#lang-switcher ul li a").each do |lang_link|
          lang_path = lang_link.attr("href")
          l = lang_path.match(%r{^/(fr)/})
          lgs << { lang: l[1], path: lang_path } if l && (!lang || l[1] == lang)
        end
        lgs
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      # Get page.
      # @param path [String] page's path
      # @return [Array<Nokogiri::HTML::Document, String>]
      def get_page(path)
        url = DOMAIN + path
        uri = URI url
        resp = Net::HTTP.get_response(uri) # .encode("UTF-8")
        case resp.code
        when "301"
          path = resp["location"]
          url = DOMAIN + path
          uri = URI url
          resp = Net::HTTP.get_response(uri) # .encode("UTF-8")
        when "404", "302"
          raise RelatonBib::RequestError, "#{url} not found."
        end
        n = 0
        while resp.body !~ /<strong/ && n < 10
          resp = Net::HTTP.get_response(uri) # .encode("UTF-8")
          n += 1
        end
        [Nokogiri::HTML(resp.body), url]
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET,
             EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
             Net::ProtocolError, Errno::ETIMEDOUT
        raise RelatonBib::RequestError, "Could not access #{url}"
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength


      # @param doc [Nokogiri:HTML::Document]
      # @param pubid [String]
      # @param edition [String]
      # @param langs [Array<Hash>]
      # @returnt [String]
      def fetch_urn(doc, pubid, edition, langs) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
        orig = pubid.split.first.downcase.split("/").join "-"
        %r{(?<=)(?<type>DATA|GUIDE|ISP|IWA|PAS|R|TR|TS|TTA)} =~ pubid
        _, part, _year, corr, = IsoBibliography.ref_components pubid
        urn = "urn:iso:std:#{orig}"
        urn += ":#{type.downcase}" if type
        urn += ":#{fetch_docnumber(doc)}"
        urn += ":-#{part}" if part
        urn += ":stage-#{stage_code(doc)}"
        urn += ":ed-#{edition}" if edition
        if corr
          corrparts = corr.split
          urn += ":#{corrparts[0].downcase}:#{corrparts[-1]}"
        end
        urn += ":#{langs.map { |l| l[:lang] }.join(',')}"
        urn
      end

      def fetch_docnumber(doc)
        item_ref(doc)&.match(/\d+/)&.to_s
      end

      # @param doc [Nokogiri::HTML::Document]
      def fetch_structuredidentifier(doc) # rubocop:disable Metrics/MethodLength
        ref = item_ref doc
        unless ref
          return RelatonIsoBib::StructuredIdentifier.new(
            project_number: "?", part_number: "", prefix: nil, id: "?",
          )
        end

        m = ref.match(/^(.*?\d+)-?((?<=-)\d+|)/)
        RelatonIsoBib::StructuredIdentifier.new(
          project_number: m[1], part: m[2], type: "ISO",
        )
      end

      def item_ref(doc)
        doc.at("//nav[contains(@class, 'heading-condensed')]/h1")&.text
      end

      # Fetch status.
      # @param doc [Nokogiri::HTML::Document]
      # @param status [String]
      # @return [Hash]
      def fetch_status(doc)
        stg, substg = stage_code(doc).split "."
        RelatonBib::DocumentStatus.new(stage: stg, substage: substg)
      end

      def stage_code(doc)
        doc.at("//ul[@class='dropdown-menu']/li[@class='active']"\
               "/a/span[@class='stage-code']").text
      end

      # def stage(stg, substg)
      #   abbr = STGABBR[stg].is_a?(Hash) ? STGABBR[stg][substg] : STGABBR[stg]
      #   RelatonBib::DocumentStatus::Stage.new value: stg, abbreviation: abbr
      # end

      # Fetch workgroup.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Hash]
      def fetch_workgroup(doc) # rubocop:disable Metrics/MethodLength
        wg_link = doc.css("div.entry-name.entry-block a")[0]
        # wg_url = DOMAIN + wg_link['href']
        workgroup = wg_link.text.split "/"
        type = workgroup[1]&.match(/^[A-Z]+/)&.to_s || "TC"
        {
          name: "International Organization for Standardization",
          abbreviation: "ISO",
          url: "www.iso.org",
          technical_committee: [{
            name: doc.css("div.entry-title")[0].text,
            identifier: wg_link.text,
            type: type,
            number: workgroup[1]&.match(/\d+/)&.to_s&.to_i,
          }],
        }
      end

      # rubocop:disable Metrics/MethodLength

      # Fetch relations.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_relations(doc) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        doc.xpath("//ul[@class='steps']/li", "//div[@class='sub-step']").reduce([]) do |a, r|
          r_type = r.at("h4", "h5").text
          date = []
          type = case r_type
                 when "Previously", "Will be replaced by" then "obsoletes"
                 when "Corrigenda / Amendments", "Revised by", "Now confirmed"
                   on = doc.xpath('//span[@class="stage-date"][contains(., "-")]').last
                   date << { type: "circulated", on: on.text } if on
                   "updates"
                 else r_type
                 end
          if ["Now", "Now under review"].include?(type) then a
          else
            a + r.css("a").map do |id|
              fref = RelatonBib::FormattedRef.new(
                content: id.text, format: "text/plain",
              )
              bibitem = RelatonIsoBib::IsoBibliographicItem.new(
                formattedref: fref, date: date,
              )
              { type: type, bibitem: bibitem }
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

      # Fetch type.
      # @param ref [String]
      # @return [String]
      def fetch_type(ref)
        %r{
          ^(?<prefix>ISO|IWA|IEC)
          (?:(/IEC|/IEEE|/PRF|/NP|/DGuide)*\s|/)
          (?<type>TS|TR|PAS|AWI|CD|FDIS|NP|DIS|WD|R|Guide|(?=\d+))
        }x =~ ref
        # return "international-standard" if type_match.nil?
        if TYPES[type] then TYPES[type]
        elsif prefix == "ISO" then "international-standard"
        elsif prefix == "IWA" then "international-workshop-agreement"
        end
        # rescue => _e
        #   puts 'Unknown document type: ' + title
      end

      # Fetch titles.
      # @param doc [Nokogiri::HTML::Document]
      # @param lang [String]
      # @return [Array<RelatonBib::TypedTitleString>]
      def fetch_title(doc, lang)
        content = doc.at(
          "//nav[contains(@class,'heading-condensed')]/h2 | "\
          "//nav[contains(@class,'heading-condensed')]/h3",
        )&.text&.gsub(/\u2014/, "-")
        return RelatonBib::TypedTitleStringCollection.new unless content

        RelatonBib::TypedTitleString.from_string content, lang, script(lang)
      end

      # Return ISO script code.
      # @param lang [String]
      # @return [String]
      def script(lang)
        case lang
        when "en", "fr" then "Latn"
          # when "ru" then "Cyrl"
        end
      end

      # rubocop:disable Metrics/MethodLength
      # Fetch dates
      # @param doc [Nokogiri::HTML::Document]
      # @param ref [String]
      # @return [Array<Hash>]
      def fetch_dates(doc, ref) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
        dates = []
        %r{^[^\s]+\s[\d-]+:(?<ref_date_str>\d{4})} =~ ref
        pub_date_str = doc.xpath("//span[@itemprop='releaseDate']").text
        if ref_date_str
          ref_date = Date.strptime ref_date_str, "%Y"
          if pub_date_str.empty?
            dates << { type: "published", on: ref_date_str }
          else
            pub_date = Date.strptime pub_date_str, "%Y"
            if pub_date.year > ref_date.year
              dates << { type: "published", on: ref_date_str }
              dates << { type: "updated", on: pub_date_str }
            else
              dates << { type: "published", on: pub_date_str }
            end
          end
        elsif !pub_date_str.empty?
          dates << { type: "published", on: pub_date_str }
        end
        dates
      end

      def fetch_contributors(ref)
        ref.sub(/\s.*/, "").split("/").reduce([]) do |mem, abbrev|
          publisher = PUBLISHERS[abbrev]
          next mem unless publisher

          publisher[:abbreviation] = abbrev
          mem << { entity: publisher, role: [type: "publisher"] }
        end
      end
      # rubocop:enable Metrics/MethodLength

      # Fetch ICS.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_ics(doc)
        doc.xpath("//strong[contains(text(), "\
                  "'ICS')]/../following-sibling::dd/div/a").map do |i|
          code = i.text.match(/[\d.]+/).to_s.split "."
          { field: code[0], group: code[1], subgroup: code[2] }
        end
      end

      # Fetch links.
      # @param doc [Nokogiri::HTML::Document]
      # @param url [String]
      # @return [Array<Hash>]
      def fetch_link(doc, url)
        links = [{ type: "src", content: url }]
        obp = doc.at_css("a#obp-preview")
        links << { type: "obp", content: obp[:href] } if obp
        rss = doc.at("//a[contains(@href, 'rss')]")
        links << { type: "rss", content: DOMAIN + rss[:href] } if rss
        pub = doc.at "//p[contains(., 'publicly available')]/a",
                     "//p[contains(., 'can be downloaded from the')]/a"
        links << { type: "pub", content: pub[:href] } if pub
        links
      end

      # Fetch copyright.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_copyright(doc)
        ref = item_ref doc
        owner_name = ref.match(/.*?(?=\s)/).to_s
        from = ref.match(/(?<=:)\d{4}/).to_s
        if from.empty?
          from = doc.xpath("//span[@itemprop='releaseDate']").text.match(/\d{4}/).to_s
        end
        [{ owner: [{ name: owner_name }], from: from }]
      end
    end
  end
end
