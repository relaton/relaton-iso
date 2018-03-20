require "algoliasearch"
require "nokogiri"
require "net/http"
require "open-uri"
# require "capybara/poltergeist"

# Capybara.request_driver :poltergeist do |app|
#   Capybara::Poltergeist::Driver.new app, js_errors: false
# end
# Capybara.default_driver = :poltergeist

Algolia.init application_id: "JCL49WV5AR", api_key: "dd1b9e1ab383f4d4817d29cd5e96d3f0"

module Isobib
  class Scrapper
    DOMAIN = "https://www.iso.org"

    class << self

      # @param text [String]
      # @return [Array<Hash>]
      def get(text)
        index = Algolia::Index.new "all_en"
        res = index.search text, facetFilters: ["category:standard"], page: 0 #, hitsPerPage: 5
        # File.open "spec/support/algolia_resp_page_#{res['page']}.json", "w" do |f|
        #   f.write res.to_json
        # end
        iso_docs = parse_pages res["hits"]
        next_page = res["page"] + 1
        while next_page < 2 do # res["nbPages"] do
          res = index.search text, facetFilters: ["category:standard"], page: next_page # , hitsPerPage: 5
          # File.open "spec/support/algolia_resp_page_#{res['page']}.json", "w" do |f|
          #   f.write res.to_json
          # end
          iso_docs += parse_pages res["hits"]
          next_page = res["page"] + 1
        end
        iso_docs
      end

      def parse_pages(hits)
        hits.map do |hit|
          url = "#{DOMAIN}#{hit["path"].match(/\/contents\/.*/).to_s}.html"
          uri = URI url
          resp = Net::HTTP.get_response uri
          if resp.code == "301"
            path = resp["location"]
            url = DOMAIN + path
            uri = URI url
            resp = Net::HTTP.get_response uri
          end

          doc = Nokogiri::HTML resp.body
          item_ref = doc.xpath("//strong[@id='itemReference']").text
            .match(/(?<=\s)(\d+)-?((?<=-)\d+|)/)

          # Fetch docid
          docid = { project_number: item_ref[1], part_number: item_ref[2] }

          # Fetch edition.
          edition = doc.xpath("//strong[contains(text(), 'Edition')]/..")
            .children.last.text.match(/\d+/).to_s

          # Fetch type.
          type_match = hit["title"].match(/^(ISO|IWA)(?:\/|\/IEC\s|\/IEEE\s|\s)(TS|TR|PAS|Guide|(?=\d+))/)
          type = case type_match[2]
            when "TS" then "technicalSpecification"
            when "TR" then "technicalReport"
            when "PAS" then "publiclyAvailableSpecification"
            when "Guide" then "guide"
            else
              if type_match[1] == "ISO"
                "internationalStandard"
              elsif type_match[1] == "IWA"
                "internationalWorkshopAgreement"
              end
          end

          # Fetch satus.
          stage, substage = doc.css('li.dropdown.active span.stage-code > strong').text.split "."

          # Fetch ICS.
          field, group, subgroup = doc
            .xpath("//strong[contains(text(), 'ICS')]/../following-sibling::dd/div/a")
            .text.match(/[\d\.]+/).to_s.split "."

          publishDate = doc.xpath("//span[@itemprop='releaseDate']").text

          # Fetch sources.
          obp_elms = doc.xpath("//a[contains(@href, '/obp/ui/')]")
          obp = obp_elms.attr("href").value if obp_elms.any?
          rss = DOMAIN + doc.xpath("//a[contains(@href, 'rss')]").attr("href").value

          # Fetch workgroup.
          wg_link = doc.css("div.entry-name.entry-block a")[0]
          wg_url = DOMAIN + wg_link["href"]
          workgroup = wg_link.text.split "/"
          wg_name = workgroup[0]
          # tc_type = "technicalCommittee"
          tc_name = doc.css("div.entry-title")[0].text
          tc_number = workgroup[1].match(/\d+/).to_s.to_i

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
              url = "#{DOMAIN}#{lang[:path]}"
              uri = URI url
              resp = Net::HTTP.get_response uri
              doc = Nokogiri::HTML resp.body # open(DOMAIN + lang[:path])
            end

            # File.open (lang[:path] || path).gsub("/", "_"), "w" do |f|
            #   f.write resp.body
            # end

            # Check if unavailable for the lang.
            next if doc.css("h5.help-block").any?

            # Fetch titles.
            title_intro, title_main, title_part = doc.css("h3[itemprop='description']")
              .text.split " -- "
            titles << {
              title_intro: title_intro,
              title_main:  title_main,
              title_par:   title_part,
              language:    lang,
              script:      "latn"
            }

            # Fetch abstracts.
            abstract_content = doc.css("div[itemprop='description'] p").text
            abstract << {
              content: abstract_content,
              lang:    lang,
              script:  "latn"
            } unless abstract_content.empty?
          end

          {
            docid:     docid,
            edition:   edition,
            titles:    titles,
            type:      type,
            docstatus: { status: hit["status"], stage: stage, substage: substage },
            ics:       { field: field, group: group, subgroup: subgroup },
            dates:     [{ type: "published", from: publishDate }],
            workgroup: {
              name:                wg_name,
              url:                 wg_url,
              technical_committee: { name: tc_name, number: tc_number }
            },
            abstract: abstract,
            source:    [
              { type: "src", content: url },
              { type: "obp", content: obp },
              { type: "rss", content: rss }
            ]
          }

          # # Get obp page with js.
          # browser = Capybara.current_session
          # browser.vivsit obp

          # langs = browser.all("div.languages div[role=button]").map do |lang_btn|
          #   lang_btn.text
          # end

          # title_splitter = [32, 226, 128, 148, 32].pack('C*').force_encoding('utf-8')
          # langs.each do |lang|
          #   lang_btn = browser.all("div.languages div[role=button]").select do |lb|
          #     lb.text == lang
          #   end

          #   unless lang_btn["class"].split.include? "v-button-down"
          #     lang_btn.click
          #   end

          #   # Fetch titles.
          #   title_intro, title_main, title_part = browser.all("div.std-title").first
          #     .text.split title_splitter
          #   titles << {
          #     title_intro: title_intro,
          #     title_main:  title_main,
          #     title_par:   title_part,
          #     language:    lang,
          #     script:      "latn"
          #   }
          # end

        end
      end
    end
  end
end