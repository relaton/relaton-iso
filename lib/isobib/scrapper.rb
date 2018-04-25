# frozen_string_literal: true

require 'algoliasearch'
require 'isobib/hit'
require 'nokogiri'
require 'net/http'
require 'isobib/workers_pool'
require 'isobib/iso_bibliographic_item'

# Capybara.request_driver :poltergeist do |app|
#   Capybara::Poltergeist::Driver.new app, js_errors: false
# end
# Capybara.default_driver = :poltergeist

Algolia.init application_id: 'JCL49WV5AR',
             api_key:        'dd1b9e1ab383f4d4817d29cd5e96d3f0'

module Isobib
  # Scrapper.
  # rubocop:disable Metrics/ModuleLength
  module Scrapper
    DOMAIN = 'https://www.iso.org'

    TYPES = {
      'TS'    => 'technicalSpecification',
      'TR'    => 'technicalReport',
      'PAS'   => 'publiclyAvailableSpecification',
      'AWI'   => 'appruvedWorkItem',
      'CD'    => 'committeeDraft',
      'FDIS'  => 'finalDraftInternationalStandard',
      'NP'    => 'newProposal',
      'DIS'   => 'draftInternationalStandard',
      'WD'    => 'workingDraft',
      'R'     => 'recommendation',
      'Guide' => 'guide'
    }.freeze

    class << self
      # @param text [String]
      # @return [Array<Hash>]
      def get(text)
        iso_workers = WorkersPool.new 4
        iso_workers.worker { |hit| iso_worker(hit, iso_workers) }
        algolia_workers = start_algolia_search(text, iso_workers)
        iso_docs = iso_workers.result
        algolia_workers.end
        algolia_workers.result
        iso_docs
      end

      # Parse page.
      # @param hit [Hash]
      # @return [Hash]
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def parse_page(hit_data)
        doc, url = get_page "/standard/#{hit_data['path'].match(/\d+$/)}.html"

        # Fetch edition.
        edition = doc.xpath("//strong[contains(text(), 'Edition')]/..")
                     .children.last.text.match(/\d+/).to_s

        titles, abstract = fetch_titles_abstract(doc)

        IsoBibliographicItem.new(
          docid:     fetch_docid(doc),
          edition:   edition,
          language:  langs(doc).map { |l| l[:lang] },
          script:    langs(doc).map { |l| script(l[:lang]) }.uniq,
          titles:    titles,
          type:      fetch_type(hit_data['title']),
          docstatus: fetch_status(doc, hit_data['status']),
          ics:       fetch_ics(doc),
          dates:     fetch_dates(doc),
          workgroup: fetch_workgroup(doc),
          abstract:  abstract,
          copyright: fetch_copyright(hit_data['title'], doc),
          source:    fetch_source(doc, url),
          relations: fetch_relations(doc)
        )
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private

      # Start algolia search workers.
      # @param text[String]
      # @param iso_workers [Isobib::WorkersPool]
      # @reaturn [Isobib::WorkersPool]
      def start_algolia_search(text, iso_workers)
        index = Algolia::Index.new 'all_en'
        algolia_workers = WorkersPool.new
        algolia_workers.worker do |page|
          algolia_worker(index, text, page, algolia_workers, iso_workers)
        end

        # Add first page so algolia worker will start.
        algolia_workers << 0
      end

      # Fetch ISO documents.
      # @param hit [Hash]
      # @param isiso_workers [Isobib::WorkersPool]
      def iso_worker(hit, iso_workers)
        print "Parse #{iso_workers.size} of #{iso_workers.nb_hits}  \r"
        parse_page hit
      end

      # Fetch hits from algolia search service.
      # @param index[Algolia::Index]
      # @param text [String]
      # @param page [Integer]
      # @param algolia_workers [Isobib::WorkersPool]
      # @param isiso_workers [Isobib::WorkersPool]
      def algolia_worker(index, text, page, algolia_workers, iso_workers)
        res = index.search text, facetFilters: ['category:standard'], page: page
        next_page = res['page'] + 1
        algolia_workers << next_page if next_page < res['nbPages']
        res['hits'].each do |hit|
          iso_workers.nb_hits = res['nbHits']
          iso_workers << hit
        end
        iso_workers.end unless next_page < res['nbPages']
      end

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
          next if d.css('h5.help-block').any?
          titles << fetch_title(d, lang[:lang])

          # Fetch abstracts.
          abstract_content = d.css("div[itemprop='description'] p").text
          next if abstract_content.empty?
          abstract << {
            content:  abstract_content,
            language: lang[:lang],
            script:   script(lang[:lang])
          }
        end
        [titles, abstract]
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Get langs.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def langs(doc)
        lgs = [{ lang: 'en' }]
        doc.css('ul#lang-switcher ul li a').each do |lang_link|
          lang_path = lang_link.attr('href')
          lang = lang_path.match(%r{^\/(fr)\/})
          lgs << { lang: lang[1], path: lang_path } if lang
        end
        lgs
      end

      # Get page.
      # @param path [String] page's path
      # @return [Array<Nokogiri::HTML::Document, String>]
      def get_page(path)
        url = DOMAIN + path
        uri = URI url
        resp = Net::HTTP.get_response uri
        if resp.code == '301'
          path = resp['location']
          url = DOMAIN + path
          uri = URI url
          resp = Net::HTTP.get_response uri
        end
        n = 0
        while resp.body !~ /<strong/ && n < 10 do
          resp = Net::HTTP.get_response uri
          n += 1
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
        stage, substage = doc.css('li.dropdown.active span.stage-code > strong')
                             .text.split '.'
        { status: status, stage: stage, substage: substage }
      end

      # Fetch workgroup.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Hash]
      def fetch_workgroup(doc)
        wg_link = doc.css('div.entry-name.entry-block a')[0]
        # wg_url = DOMAIN + wg_link['href']
        workgroup = wg_link.text.split '/'
        { name:                'International Organization for Standardization',
          abbreviation:        'ISO',
          url:                 'www.iso.org',
          technical_committee: {
            name:   doc.css('div.entry-title')[0].text,
            type:   'technicalCommittee',
            number: workgroup[1].match(/\d+/).to_s.to_i
          } }
      end

      # Fetch relations.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      # rubocop:disable Metrics/MethodLength
      def fetch_relations(doc)
        doc.css('ul.steps li').inject([]) do |a, r|
          r_type = r.css('strong').text
          type = case r_type
                 when 'Previously', 'Will be replaced by' then 'obsoletes'
                 when 'Corrigenda/Amendments', 'Revised by', 'Now confirmed'
                   'updates'
                 else r_type
                 end
          if ['Now', 'Now under review'].include? type
            a
          else
            a + r.css('a').map do |id|
              { type: type, identifier: id.text, url: id['href'] }
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

      # Fetch type.
      # @param title [String]
      # @return [String]
      def fetch_type(title)
        type_match = title.match(%r{^(ISO|IWA|IEC)(?:\/IEC\s|\/IEEE\s|\/PRF\s|
          \/NP\s|\s|\/)(TS|TR|PAS|AWI|CD|FDIS|NP|DIS|WD|R|Guide|(?=\d+))}x)
        if TYPES[type_match[2]]
          TYPES[type_match[2]]
        elsif type_match[1] == 'ISO'
          'international-standard'
        elsif type_match[1] == 'IWA'
          'international-workshop-agreement'
        end
        # rescue => _e
        #   puts 'Unknown document type: ' + title
      end

      # Fetch titles.
      # @param doc [Nokogiri::HTML::Document]
      # @param lang [String]
      # @return [Hash]
      def fetch_title(doc, lang)
        intro, main, part = doc.css("h3[itemprop='description']")
                               .text.split ' -- '
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
        when 'en', 'fr' then 'Latn'
        end
      end

      # Fetch dates
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_dates(doc)
        dates = []
        publish_date = doc.xpath("//span[@itemprop='releaseDate']").text
        unless publish_date.empty?
          dates << { type: 'published', from: publish_date }
        end
        dates
      end

      # Fetch ICS.
      # @param doc [Nokogiri::HTML::Document]
      # @return [Array<Hash>]
      def fetch_ics(doc)
        doc.xpath('//strong[contains(text(), '\
        "'ICS')]/../following-sibling::dd/div/a").map do |i|
          code = i.text.match(/[\d\.]+/).to_s.split '.'
          { field: code[0], group: code[1], subgroup: code[2] }
        end
      end

      # Fetch sources.
      # @param doc [Nokogiri::HTML::Document]
      # @param url [String]
      # @return [Array<Hash>]
      def fetch_source(doc, url)
        obp_elms = doc.xpath("//a[contains(@href, '/obp/ui/')]")
        obp = obp_elms.attr('href').value if obp_elms.any?
        rss = DOMAIN + doc.xpath("//a[contains(@href, 'rss')]").attr('href')
                          .value
        [
          { type: 'src', content: url },
          { type: 'obp', content: obp },
          { type: 'rss', content: rss }
        ]
      end

      # Fetch copyright.
      # @param title [String]
      # @return [Hash]
      def fetch_copyright(title, doc)
        owner_name = title.match(/.*?(?=\s)/).to_s
        from = title.match(/(?<=:)\d{4}/).to_s
        if from.empty?
          from = doc.xpath("//span[@itemprop='releaseDate']").text
                    .match(/\d{4}/).to_s
        end
        { owner: { name: owner_name }, from: from }
      end
    end

    # private
    #
    # def next_hits_page(next_page)
    #   page = @index.search @text, facetFilters: ['category:standard'],
    #                               page:         next_page
    #   page.each do |key, value|
    #     if key == 'hits'
    #       @docs[key] += value
    #     else
    #       @docs[key] = value
    #     end
    #   end
    # end
  end
  # rubocop:enable Metrics/ModuleLength
end
