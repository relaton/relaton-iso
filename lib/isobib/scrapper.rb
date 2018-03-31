require "algoliasearch"
# require "nokogiri"
# require "net/http"
# require "open-uri"
# require "isobib/workers_pool"
require "isobib/hit"
require "nokogiri"
require "net/http"
# require "open-uri"
require "isobib/workers_pool"
# require "capybara/poltergeist"

# Capybara.request_driver :poltergeist do |app|
#   Capybara::Poltergeist::Driver.new app, js_errors: false
# end
# Capybara.default_driver = :poltergeist

Algolia.init application_id: "JCL49WV5AR", api_key: "dd1b9e1ab383f4d4817d29cd5e96d3f0"

module Isobib
  class Scrapper
    DOMAIN = "https://www.iso.org"

    def initialize(text)
      @text = text
      @index = Algolia::Index.new "all_en"
      @docs = @index.search text, facetFilters: ["category:standard"]
      @nb_hits = @docs["nbHits"]
    end

    def each(&block)
      next_page = @docs["page"] + 1
      @nb_hits.times do |n|
        unless next_page * @docs["hitsPerPage"] > n
          @docs = @index.search @text, facetFilters: ["category:standard"], page: next_page
          next_page = @docs["page"] + 1
        end
        idx = n - @docs["page"] * @docs["hitsPerPage"]
        yield Hit.new(@docs["hits"][idx])
      end
    end

    class << self

      # @param text [String]
      # @return [Array<Hash>]
      def get(text)
        index = Algolia::Index.new "all_en"

        nb_hits = 0
        iso_workers = WorkersPool.new 4 do |hit|
          print "Parse #{iso_workers.size} of #{nb_hits}  \r"
          parse_page hit
        end
        
        algolia_workers = WorkersPool.new do |page|
          res = index.search text, facetFilters: ["category:standard"], page: page
          next_page = res["page"] + 1
          algolia_workers << next_page if next_page < res["nbPages"]
          res["hits"].each do |hit|
            nb_hits = res["nbHits"]
            iso_workers << hit
          end
          iso_workers.end unless next_page < res["nbPages"]
        end

        algolia_workers << 0

        iso_docs = iso_workers.result
        algolia_workers.end
        algolia_workers.result
        iso_docs
      end

      # Parse page.
      # @param hit [Hash]
      # @return [Hash]
      def parse_page(hit_data)
        doc, url = get_page "#{hit_data["path"].match(/\/contents\/.*/).to_s}.html"

        # Fetch edition.
        edition = doc.xpath("//strong[contains(text(), 'Edition')]/..")
          .children.last.text.match(/\d+/).to_s

        langs = [{ lang: "en" }]
        langs += doc.css("ul#lang-switcher ul li a").map do |lang_link|
          lang_path = lang_link.attr("href")
          lang = lang_path.match(/^\/(\w{2})\//)[1]
          { lang: lang, path: lang_path }
        end

        titles   = []
        abstract = []
        langs.each do |lang|
          # Don't need to get page for en. We already have it.
          if lang[:path]
            d, _url = get_page lang[:path]
          else
            d = doc
          end

          # Check if unavailable for the lang.
          next if d.css("h5.help-block").any?

          titles << fetch_title(d, lang[:lang])

          # Fetch abstracts.
          abstract_content = d.css("div[itemprop='description'] p").text
          abstract << {
            content:  abstract_content,
            language: lang[:lang],
            script:   script(lang[:lang])
          } unless abstract_content.empty?
        end

        IsoBibliographicItem.new(
          docid:     fetch_docid(doc),
          edition:   edition,
          titles:    titles,
          type:      fetch_type(hit_data["title"]),
          docstatus: fetch_status(doc, hit_data["status"]),
          ics:       fetch_ics(doc),
          dates:     fetch_dates(doc),
          workgroup: fetch_workgroup(doc),
          abstract:  abstract,
          copyright: fetch_copyright(hit_data["title"], doc),
          source:    fetch_source(doc, url),
          relations: fetch_relations(doc)
        )
      end

      # Get page.
      # @param path [String] page's path
      # @return [Array<Nokogiri::HTML::Document, String>]
      def get_page(path)
        url = DOMAIN + path
        uri = URI url
        resp = Net::HTTP.get_response uri
        if resp.code == "301"
          path = resp["location"]
          url = DOMAIN + path
          uri = URI url
          resp = Net::HTTP.get_response uri
        end
        [Nokogiri::HTML(resp.body), url]
      end

      # Fetch docid.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Hash]
      def fetch_docid(doc)
        item_ref = doc.xpath("//strong[@id='itemReference']").text
          .match(/(?<=\s)(\d+)-?((?<=-)\d+|)/)
        { project_number: item_ref[1], part_number: item_ref[2] }
      end

      # Fetch status.
      # @param doc [Nokogiri::HTML::Document]
      # @param status [String]
      # @return [Hash]
      def fetch_status(doc, status)
        stage, substage = doc.css('li.dropdown.active span.stage-code > strong').text.split "."
        { status: status, stage: stage, substage: substage }       
      end

      # Fetch workgroup.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Hash]
      def fetch_workgroup(doc)
        wg_link = doc.css("div.entry-name.entry-block a")[0]
        wg_url = DOMAIN + wg_link["href"]
        workgroup = wg_link.text.split "/"
        wg_name = workgroup[0]
        tc_type = "technicalCommittee"
        tc_name = doc.css("div.entry-title")[0].text
        tc_number = workgroup[1].match(/\d+/).to_s.to_i
        {
          name:                wg_name,
          url:                 wg_url,
          technical_committee: { name: tc_name, type: tc_type, number: tc_number }
        }
      end

      # Fetch relations.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_relations(doc)
        doc.css('ul.steps li').map do |r|
          r_type = r.css('strong').text
          r_identifier = r.css('a').children.last.text
          { type: r_type, identifier: r_identifier }
        end
      end

      # Fetch type.
      # @param title [String]
      # @return [String]
      def fetch_type(title)
        type_match = title.match(/^(ISO|IWA)(?:\/IEC\s|\/IEEE\s|\/PRF\s|\/NP\s|\s|\/)(TS|TR|PAS|AWI|CD|FDIS|NP|DIS|WD|R|Guide|(?=\d+))/)
        case type_match[2]
          when "TS" then "technicalSpecification"
          when "TR" then "technicalReport"
          when "PAS" then "publiclyAvailableSpecification"
          when "AWI" then "appruvedWorkItem"
          when "CD" then "committeeDraft"
          when "FDIS" then "finalDraftInternationalStandard"
          when "NP" then "newProposal"
          when "DIS" then "draftInternationalStandard"
          when "WD" then "workingDraft"
          when "R" then "recommendation"
          when "Guide" then "guide"
          else
            if type_match[1] == "ISO"
              "internationalStandard"
            elsif type_match[1] == "IWA"
              "internationalWorkshopAgreement"
            end
        end
      rescue
        puts "Unknown document type: " + title
      end

      # Fetch titles.
      # @param doc [Nokogiri::HTML::Document]
      # @param lang [String]
      # @return [Hash]
      def fetch_title(doc, lang)
        intro, main, part = doc.css("h3[itemprop='description']").text.split " -- "
        {
          title_intro: intro,
          title_main:  main,
          title_part:  part,
          language:    lang,
          script:      script(lang)
        }
      end

      # Return ISO script code.
      # @param lang [String]
      # @return [String]
      def script(lang)
        case lang
        when "en", "fr" then "latn"
        when "ru" then "cyrl"
        end
      end

      # Fetch dates
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_dates(doc)
        dates = []
        publish_date = doc.xpath("//span[@itemprop='releaseDate']").text
        dates << { type: "published", from: publish_date } unless publish_date.empty?
        dates
      end

      # Fetch ICS.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_ics(doc)
        doc.xpath("//strong[contains(text(), 'ICS')]/../following-sibling::dd/div/a")
        .map do |i|
          code = i.text.match(/[\d\.]+/).to_s.split "."
          { field: code[0], group: code[1], subgroup: code[2] }
        end
      end

      # Fetch sources.
      # @param doc [Nokogiri::HTML::Document]
      # @param url [String]
      # @return [Array<Hash>]
      def fetch_source(doc, url)
        obp_elms = doc.xpath("//a[contains(@href, '/obp/ui/')]")
        obp = obp_elms.attr("href").value if obp_elms.any?
        rss = DOMAIN + doc.xpath("//a[contains(@href, 'rss')]").attr("href").value
        [
          { type: "src", content: url },
          { type: "obp", content: obp },
          { type: "rss", content: rss }
        ]
      end

      # Fetch copyright.
      # @param title [String]
      # @return [Hash]
      def fetch_copyright(title, doc)
        owner_name = title.match(/.*?(?=\s)/).to_s
        from = title.match(/(?<=:)\d{4}/).to_s
        from = doc.xpath("//span[@itemprop='releaseDate']").text.match(/\d{4}/).to_s if from.empty?
        { owner: { name: owner_name }, from: from }
      end
    end
  end
end