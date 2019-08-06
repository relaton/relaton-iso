# frozen_string_literal: true

require "relaton_iso_bib"
require "relaton_iso/hit"
require "nokogiri"
require "net/http"

module RelatonIso
  # Scrapper.
  # rubocop:disable Metrics/ModuleLength
  module Scrapper
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

    class << self
      # @param text [String]
      # @return [Array<Hash>]
      # def get(text)
      #   iso_workers = RelatonBib::WorkersPool.new 4
      #   iso_workers.worker { |hit| iso_worker(hit, iso_workers) }
      #   algolia_workers = start_algolia_search(text, iso_workers)
      #   iso_docs = iso_workers.result
      #   algolia_workers.end
      #   algolia_workers.result
      #   iso_docs
      # rescue
      #   warn "Could not connect to http://www.iso.org"
      #   []
      # end

      # Parse page.
      # @param hit [Hash]
      # @return [Hash]
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def parse_page(hit_data)
        path = "/contents/data/standard#{hit_data["splitPath"]}/#{hit_data["csnumber"]}.html"
        doc, url = get_page path

        # Fetch edition.
        edition = doc&.xpath("//strong[contains(text(), 'Edition')]/..")&.
          children&.last&.text&.match(/\d+/)&.to_s

        titles, abstract = fetch_titles_abstract(doc)

        RelatonIsoBib::IsoBibliographicItem.new(
          fetched: Date.today.to_s,
          docid: fetch_docid(doc),
          edition: edition,
          language: langs(doc).map { |l| l[:lang] },
          script: langs(doc).map { |l| script(l[:lang]) }.uniq,
          title: titles,
          type: fetch_type(hit_data["docRef"]),
          docstatus: fetch_status(doc),
          ics: fetch_ics(doc),
          date: fetch_dates(doc, hit_data["docRef"]),
          contributor: fetch_contributors(hit_data["docRef"]),
          editorialgroup: fetch_workgroup(doc),
          abstract: abstract,
          copyright: fetch_copyright(hit_data["docRef"], doc),
          link: fetch_link(doc, url),
          relation: fetch_relations(doc),
          structuredidentifier: fetch_structuredidentifier(doc),
        )
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private

      # Start algolia search workers.
      # @param text[String]
      # @param iso_workers [RelatonBib::WorkersPool]
      # @reaturn [RelatonBib::WorkersPool]
      # def start_algolia_search(text, iso_workers)
      #   index = Algolia::Index.new "all_en"
      #   algolia_workers = RelatonBib::WorkersPool.new
      #   algolia_workers.worker do |page|
      #     algolia_worker(index, text, page, algolia_workers, iso_workers)
      #   end

      #   # Add first page so algolia worker will start.
      #   algolia_workers << 0
      # end

      # Fetch ISO documents.
      # @param hit [Hash]
      # @param isiso_workers [RelatonIso::WorkersPool]
      # def iso_worker(hit, iso_workers)
      #   print "Parse #{iso_workers.size} of #{iso_workers.nb_hits}  \r"
      #   parse_page hit
      # end

      # Fetch hits from algolia search service.
      # @param index[Algolia::Index]
      # @param text [String]
      # @param page [Integer]
      # @param algolia_workers [RelatonBib::WorkersPool]
      # @param isiso_workers [RelatonBib::WorkersPool]
      # def algolia_worker(index, text, page, algolia_workers, iso_workers)
      #   res = index.search text, facetFilters: ["category:standard"], page: page
      #   next_page = res["page"] + 1
      #   algolia_workers << next_page if next_page < res["nbPages"]
      #   res["hits"].each do |hit|
      #     iso_workers.nb_hits = res["nbHits"]
      #     iso_workers << hit
      #   end
      #   iso_workers.end unless next_page < res["nbPages"]
      # end

      # Fetch titles and abstracts.
      # @param doc [Nokigiri::HTML::Document]
      # @return [Array<Array>]
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def fetch_titles_abstract(doc)
        titles   = []
        abstract = []
        langs(doc).each do |lang|
          # Don't need to get page for en. We already have it.
          d = lang[:path] ? get_page(lang[:path])[0] : doc

          # Check if unavailable for the lang.
          next if d.css("h5.help-block").any?

          titles << fetch_title(d, lang[:lang])

          # Fetch abstracts.
          abstract_content = d.css("div[itemprop='description'] p").text
          next if abstract_content.empty?

          abstract << {
            content: abstract_content,
            language: lang[:lang],
            script: script(lang[:lang]),
            format: "text/plain",
          }
        end
        [titles, abstract]
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Get langs.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def langs(doc)
        lgs = [{ lang: "en" }]
        doc.css("ul#lang-switcher ul li a").each do |lang_link|
          lang_path = lang_link.attr("href")
          lang = lang_path.match(%r{^\/(fr)\/})
          lgs << { lang: lang[1], path: lang_path } if lang
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
        when "404"
          raise RelatonBib::RequestError, "#{url} not found."
        end
        n = 0
        while resp.body !~ /<strong/ && n < 10
          resp = Net::HTTP.get_response(uri) # .encode("UTF-8")
          n += 1
        end
        [Nokogiri::HTML(resp.body), url]
      rescue SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError,
             OpenSSL::SSL::SSLError
        raise RelatonBib::RequestError, "Could not access #{url}"
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Fetch docid.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<RelatonBib::DocumentIdentifier>]
      def fetch_docid(doc)
        item_ref = doc.at("//strong[@id='itemReference']")
        return [] unless item_ref

        [RelatonBib::DocumentIdentifier.new(id: item_ref.text, type: "ISO")]
      end

      # @param doc [Nokogiri::HTML::Document]
      def fetch_structuredidentifier(doc)
        item_ref = doc.at("//strong[@id='itemReference']")
        unless item_ref
          return RelatonIsoBib::StructuredIdentifier.new(
            project_number: "?", part_number: "", prefix: nil, id: "?",
          )
        end

        m = item_ref.text.match(/^(.*?\d+)-?((?<=-)\d+|)/)
        RelatonIsoBib::StructuredIdentifier.new(
          project_number: m[1], part_number: m[2], prefix: nil,
          id: item_ref.text, type: "ISO"
        )
      end

      # Fetch status.
      # @param doc [Nokogiri::HTML::Document]
      # @param status [String]
      # @return [Hash]
      def fetch_status(doc)
        stage, substage = doc.css("li.dropdown.active span.stage-code > strong").text.split "."
        RelatonBib::DocumentStatus.new(stage: stage, substage: substage)
      end

      # Fetch workgroup.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Hash]
      def fetch_workgroup(doc)
        wg_link = doc.css("div.entry-name.entry-block a")[0]
        # wg_url = DOMAIN + wg_link['href']
        workgroup = wg_link.text.split "/"
        {
          name: "International Organization for Standardization",
          abbreviation: "ISO",
          url: "www.iso.org",
          technical_committee: [{
            name: wg_link.text + doc.css("div.entry-title")[0].text,
            type: "TC",
            number: workgroup[1]&.match(/\d+/)&.to_s&.to_i,
          }],
        }
      end

      # rubocop:disable Metrics/MethodLength

      # Fetch relations.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_relations(doc)
        doc.css("ul.steps li").reduce([]) do |a, r|
          r_type = r.css("strong").text
          type = case r_type
                 when "Previously", "Will be replaced by" then "obsoletes"
                 when "Corrigenda/Amendments", "Revised by", "Now confirmed"
                   "updates"
                 else r_type
                 end
          if ["Now", "Now under review"].include? type
            a
          else
            a + r.css("a").map do |id|
              fref = RelatonBib::FormattedRef.new(
                content: id.text, format: "text/plain",
              )
              bibitem = RelatonIsoBib::IsoBibliographicItem.new(
                formattedref: fref,
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
      # @return [Hash]
      def fetch_title(doc, lang)
        content = doc.at(
          "//h3[@itemprop='description'] | //h2[@itemprop='description']",
        )&.text
        RelatonIsoBib::HashConverter.split_title content, lang, script(lang)
      end

      # Return ISO script code.
      # @param lang [String]
      # @return [String]
      def script(lang)
        case lang
        when "en", "fr" then "Latn"
        end
      end

      # rubocop:disable Metrics/MethodLength
      # Fetch dates
      # @param doc [Nokogiri::HTML::Document]
      # @param ref [String]
      # @return [Array<Hash>]
      def fetch_dates(doc, ref)
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
        ref.sub(/\s.*/, "").split("/").map do |abbrev|
          case abbrev
          when "IEC"
            name = "International Electrotechnical Commission"
            url  = "www.iec.ch"
          else
            name = "International Organization for Standardization"
            url = "www.iso.org"
          end
          { entity: { name: name, url: url, abbreviation: abbrev },
            role: [type: "publisher"] }
        end
      end
      # rubocop:enable Metrics/MethodLength

      # Fetch ICS.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_ics(doc)
        doc.xpath("//strong[contains(text(), "\
                  "'ICS')]/../following-sibling::dd/div/a").map do |i|
          code = i.text.match(/[\d\.]+/).to_s.split "."
          { field: code[0], group: code[1], subgroup: code[2] }
        end
      end

      # Fetch links.
      # @param doc [Nokogiri::HTML::Document]
      # @param url [String]
      # @return [Array<Hash>]
      def fetch_link(doc, url)
        links = [{ type: "src", content: url }]
        obp = doc.at("//a[contains(@href, '/obp/ui/')]")
        links << { type: "obp", content: obp[:href] } if obp
        rss = doc.at("//a[contains(@href, 'rss')]")
        links << { type: "rss", content: DOMAIN + rss[:href] } if rss
        pub = doc.at "//p[contains(., 'publicly available')]/a"
        links << { type: "pub", content: pub[:href] } if pub
        links
      end

      # Fetch copyright.
      # @param ref [String]
      # @param doc [Nokogiri::HTML::Document]
      # @return [Hash]
      def fetch_copyright(ref, doc)
        owner_name = ref.match(/.*?(?=\s)/).to_s
        from = ref.match(/(?<=:)\d{4}/).to_s
        if from.empty?
          from = doc.xpath("//span[@itemprop='releaseDate']").text.match(/\d{4}/).to_s
        end
        { owner: { name: owner_name }, from: from }
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
