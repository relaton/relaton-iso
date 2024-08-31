# frozen_string_literal: true

module RelatonIso
  # Scrapper.
  class Scrapper # rubocop:disable Metrics/ModuleLength
    DOMAIN = "https://www.iso.org"

    TYPES = {
      "TS" => "technical-specification",
      "DTS" => "technical-specification",
      "TR" => "technical-report",
      "DTR" => "technical-report",
      "PAS" => "publicly-available-specification",
      # "AWI" => "approvedWorkItem",
      # "CD" => "committeeDraft",
      # "FDIS" => "finalDraftInternationalStandard",
      # "NP" => "newProposal",
      # "DIS" => "draftInternationalStandard",
      # "WD" => "workingDraft",
      # "R" => "recommendation",
      "Guide" => "guide",
      "ISO" => "international-standard",
      "IEC" => "international-standard",
      "IWA" => "international-workshop-agreement",
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

    # extend self

    def initialize(lang, errors)
      @lang = lang
      @errors = errors
    end

    # Parse page.
    # @param path [String] page path
    # @param lang [String, nil] language
    # @param errors [Hash] collection of parsing errors
    # @return [RelatonIsoBib::IsoBibliographicItem]
    def self.parse_page(path, lang: nil, errors: {})
      new(lang, errors).parse(path)
    end

    def parse(path) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      @doc, url = get_page path
      titles, abstract, langs = fetch_titles_abstract

      RelatonIsoBib::IsoBibliographicItem.new(
        docid: fetch_relaton_docids,
        docnumber: fetch_docnumber,
        edition: edition,
        language: langs.map { |l| l[:lang] },
        script: langs.map { |l| script(l[:lang]) }.uniq,
        title: titles,
        doctype: fetch_type,
        docstatus: fetch_status,
        ics: fetch_ics,
        date: fetch_dates,
        contributor: fetch_contributors,
        editorialgroup: fetch_workgroup,
        abstract: abstract,
        copyright: fetch_copyright,
        link: fetch_link(url),
        relation: fetch_relations,
        place: ["Geneva"],
        structuredidentifier: fetch_structuredidentifier,
      )
    end

    def id
      return @id if defined?(@id)

      did = @doc.at("//h1/span[1]")
      @errors[:id] &&= did.nil?
      @id = did && did.text.split(" | ").first.strip
    end

    def pubid
      return @pubid if @pubid

      @pubid = Pubid::Iso::Identifier.parse(id)
      @pubid.root.edition ||= edition if @pubid.base
      @pubid
    rescue StandardError => e
      Util.error "Failed to parse pubid from #{id}: #{e.message}"
    end

    def edition
      return @edition if defined?(@edition)

      ed = @doc.at("//div[div[.='Edition']]/text()[last()]")
      @errors[:edition] &&= ed.nil?
      @edition = ed && ed.text.match(/\d+$/).to_s
    end

    #
    # Create document ids.
    #
    # @return [Array<RelatonBib::DocumentIdentifier>]
    #
    def fetch_relaton_docids
      pubid.stage ||= Pubid::Iso::Identifier.parse_stage(stage_code)
      [
        DocumentIdentifier.new(id: pubid, type: "ISO", primary: true),
        RelatonBib::DocumentIdentifier.new(id: isoref, type: "iso-reference"),
        DocumentIdentifier.new(id: pubid, type: "URN"),
      ]
    end

    #
    # Create ISO reference identifier with English language.
    #
    # @return [String] English reference identifier
    #
    def isoref
      params = pubid.to_h.reject { |k, _| k == :typed_stage }
      Pubid::Iso::Identifier.create(language: "en", **params).to_s(format: :ref_num_short)
    end

    private

    # Fetch titles and abstracts.
    # @return [Array<Array>]
    def fetch_titles_abstract # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      titles   = RelatonBib::TypedTitleStringCollection.new
      abstract = []
      langs = languages.each_with_object([]) do |l, s|
        # Don't need to get page for en. We already have it.
        d = l[:path] ? get_page(l[:path])[0] : @doc
        unless d.at("//h5[@class='help-block'][.='недоступно на русском языке']")
          s << l
          titles += fetch_title(d, l[:lang])

          abstr = parse_abstract(d, l[:lang])
          abstract << abstr if abstr
        end
      end
      [titles, abstract, langs]
    end

    def parse_abstract(doc, lang)
      abstract_content = doc.xpath(
        "//div[@itemprop='description']/p|//div[@itemprop='description']/ul/li",
      ).map { |a| a.name == "li" ? "- #{a.text}" : a.text }.reject(&:empty?).join("\n")
      @errors[:abstract] &&= abstract_content.empty?
      return if abstract_content.empty?

      { content: abstract_content, language: lang, script: script(lang), format: "text/plain" }
    end

    # Returns available languages.
    # @return [Array<Hash>]
    def languages
      lgs = [{ lang: "en" }]
      @doc.css("li#lang-switcher ul li a").each do |lang_link|
        lang_path = lang_link.attr("href")
        l = lang_path.match(%r{^/(fr)/})
        lgs << { lang: l[1], path: lang_path } if l && (!@lang || l[1] != @lang)
      end
      @errors[:language] &&= lgs.size == 1
      lgs
    end

    # Get page.
    # @param path [String] page's path
    # @return [Array<Nokogiri::HTML::Document, String>]
    def get_page(path) # rubocop:disable Metrics/MethodLength
      try = 0
      begin
        resp, uri = get_redirection path
        doc = try_if_fail resp, uri
        [doc, uri.to_s]
      rescue  SocketError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET,
              EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
              Net::ProtocolError, Errno::ETIMEDOUT
        try += 1
        raise RelatonBib::RequestError, "Could not access #{DOMAIN}#{path}" if try > 3

        sleep 1
        retry
      end
    end

    #
    # Get the page from the given path. If the page is redirected, get the
    # page from the new path.
    #
    # @param [String] path path to the page
    #
    # @return [Array<Net::HTTPOK, URI>] HTTP response and URI
    # @raise [RelatonBib::RequestError] if the page is not found
    #
    def get_redirection(path) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      uri = URI(DOMAIN + path)
      try = 0
      begin
        get_response uri
      rescue Errno::EPIPE => e
        try += 1
        retry if check_try try, uri
        raise e
      end
    end

    def check_try(try, uri)
      if try < 3
        warn "Timeout fetching #{uri}, retrying..."
        sleep 1
        true
      end
    end

    def get_response(uri, try = 0)
      raise RelatonBib::RequestError, "#{uri} not found." if try > 3

      resp = Net::HTTP.get_response(uri)
      case resp.code
      when "200" then [resp, uri]
      when "301" then get_redirection(resp["location"])
      when "404" then raise RelatonBib::RequestError, "#{uri} not found."
      else
        sleep (2**try)
        get_response uri, try + 1
      end
    end

    #
    # The iso.org site fails to respond sometimes. This method tries to get
    # the response again.
    #
    # @param [Net::HTTPOK] resp HTTP response
    # @param [URI::HTTPS] uri URI of the page
    #
    # @return [Nokogiri::HTML4::Document] document
    # @raise [RelatonBib::RequestError] if the page could not be parsed
    #
    def try_if_fail(resp, uri)
      10.times do
        doc = Nokogiri::HTML(resp.body)
        # stop trying if page has a document id
        return doc if item_ref(doc)

        resp = Net::HTTP.get_response(uri)
      end
      raise RelatonBib::RequestError, "Could not parse the page #{uri}"
    end

    #
    # Generate docnumber.
    #
    # @return [String] docnumber
    #
    def fetch_docnumber
      pubid.to_s.match(/\d+/)&.to_s
    end

    #
    # Parse structuredidentifier.
    #
    # @return [RelatonBib::StructuredIdentifier] structured identifier
    #
    def fetch_structuredidentifier # rubocop:disable Metrics/MethodLength
      RelatonIsoBib::StructuredIdentifier.new(
        project_number: "#{pubid.root.publisher} #{pubid.root.number}",
        part: pubid.root.part&.to_s, # &.sub(/^-/, ""),
        type: pubid.root.publisher,
      )
    end

    #
    # Parse ID from the document.
    #
    # @param [Nokogiri::HTML::Document] doc document to parse
    #
    # @return [String, nil] ID
    #
    def item_ref(doc)
      ref = doc.at("//main//section/div/div/div//h1/span[1]")
      @errors[:reference] &&= ref.nil?
      ref&.text&.strip
    end

    # Fetch status.
    # @return [RelatonBib::DocumentStatus]
    def fetch_status
      stg, substg = stage_code.split "."
      RelatonBib::DocumentStatus.new(stage: stg, substage: substg)
    end

    def stage_code
      return @stage_code if defined?(@stage_code)

      stc = @doc.at("//ul[@class='dropdown-menu']/li[@class='active']/a/span[@class='stage-code']")
      @errors[:stage] &&= stc.nil?
      @stage_code = stc&.text
    end

    # def stage(stg, substg)
    #   abbr = STGABBR[stg].is_a?(Hash) ? STGABBR[stg][substg] : STGABBR[stg]
    #   RelatonBib::DocumentStatus::Stage.new value: stg, abbreviation: abbr
    # end

    # Fetch workgroup.
    # @param doc [Nokogiri::HTML::Document]
    # @return [RelatonIsoBib::EditorialGroup, nil]
    def fetch_workgroup # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      wg = @doc.at("//div[contains(., 'Technical Committe')]/following-sibling::span/a")
      @errors[:workgroup] &&= wg.nil?
      return unless wg

      workgroup = wg.text.split "/"
      type = workgroup[1]&.match(/^[A-Z]+/)&.to_s || "TC"
      # {
      #   name: "International Organization for Standardization",
      #   abbreviation: "ISO",
      #   url: "www.iso.org",
      # }
      tc_numb = workgroup[1]&.match(/\d+/)&.to_s&.to_i
      tc_name = wg[:title]
      tc = RelatonBib::WorkGroup.new(name: tc_name, identifier: wg.text,
                                     type: type, number: tc_numb)
      RelatonIsoBib::EditorialGroup.new(technical_committee: [tc])
    end

    # Fetch relations.
    # @return [Array<Hash>]
    def fetch_relations
      types = ["Now", "Now under review"]
      rels = @doc.xpath(
        "//ul[@class='steps']/li", "//div[contains(@class, 'sub-step')]"
      ).reduce([]) do |a, r|
        type, date = relation_type(r.at("h4", "h5").text.strip)
        next a if types.include?(type)

        a + create_relations(r, type, date)
      end
      @errors[:relation] &&= rels.empty?
      rels
    end

    #
    # Parse relation type and dates.
    #
    # @param [String] type parsed type
    #
    # @return [Array<String,Array>] type and dates
    #
    def relation_type(type)
      date = []
      t = case type.strip
          when "Previously", "Will be replaced by" then "obsoletes"
          when /Corrigenda|Amendments|Revised by|Now confirmed|replaced by/
            on = @doc.xpath('//span[@class="stage-date"][contains(., "-")]').last
            date << { type: "circulated", on: on.text } if on
            "updates"
          else type
          end
      [t, date]
    end

    #
    # Create relations.
    #
    # @param [Nokogiri::HTML::Element] rel relation element
    # @param [String] type relation type
    # @param [Hash{Symbol=>String}] date relation document date
    # @option date [String] :type date type
    # @option date [String] :on date
    #
    # @return [Array<Hash>] Relations
    #
    def create_relations(rel, type, date)
      rel.css("a").map do |rid|
        docid = DocumentIdentifier.new(type: "ISO", id: rid.text, primary: true)
        fref = RelatonBib::FormattedRef.new(content: rid.text, format: "text/plain")
        bibitem = RelatonIsoBib::IsoBibliographicItem.new(
          docid: [docid], formattedref: fref, date: date,
        )
        { type: type, bibitem: bibitem }
      end
    end

    # Fetch type.
    # @return [String]
    def fetch_type
      %r{
        ^(?<prefix>ISO|IWA|IEC)
        (?:(?:/CIE|/IEC|/IEEE|/PRF|/NP|/SAE|/HL7|/DGuide)*\s|/)
        (?<type>TS|TR|PAS|AWI|CD|FDIS|NP|DIS|WD|R|DTS|DTR|ISP|PWI|Guide|(?=\d+))
      }x =~ id
      type = TYPES[type] || TYPES[prefix] || "international-standard"
      RelatonIsoBib::DocumentType.new(type: type)
    end

    # Fetch titles.
    # @param doc [Nokogiri::HTML::Document]
    # @param lang [String]
    # @return [Array<RelatonBib::TypedTitleString>]
    def fetch_title(doc, lang) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
      types = %w[title-intro title-main title-part]
      ttls = parse_titles(doc)
      title = RelatonBib::TypedTitleStringCollection.new
      ttls.each.with_index do |p, i|
        next unless p

        title << RelatonBib::TypedTitleString.new(
          type: types[i], content: p, language: lang, script: script(lang),
        )
      end.compact
      main = title.map { |t| t.title.content }.join " - "
      title << RelatonBib::TypedTitleString.new(type: "main", content: main, language: lang, script: script(lang))
    end

    def parse_titles(doc)
      # head = doc.at "//nav[contains(@class,'heading-condensed')]"
      ttls = doc.xpath("//h1[@class='stdTitle']/span[position()>1]").map(&:text)
      return ttls if @errors[:title] &&= ttls.empty?

      ttls[0, 1] = ttls[0].split(/\s(?:-|\u2014)\s/) # if ttls.size == 1
      case ttls.size
      when 0, 1 then [nil, ttls.first, nil]
      else RelatonBib::TypedTitleString.intro_or_part ttls
      end
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

    # Fetch dates
    # @return [Array<Hash>]
    def fetch_dates # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      dates = []
      %r{^[^\s]+\s[\d-]+:(?<ref_date_str>\d{4})} =~ id
      pub_date_str = @doc.at("//span[@itemprop='releaseDate']")
      @errors[:date_pub] &&= pub_date_str.nil?
      if ref_date_str
        dates += parse_date_from_id ref_date_str, pub_date_str
      elsif pub_date_str
        dates << { type: "published", on: pub_date_str.text }
      end
      corr_data = @doc.at "//span[@itemprop='dateModified']"
      @errors[:date_corr] &&= corr_data.nil?
      dates << { type: "corrected", on: corr_data.text } if corr_data
      dates
    end

    def parse_date_from_id(ref_date_str, pub_date_str) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      dates = []
      ref_date = Date.strptime ref_date_str, "%Y"
      if pub_date_str.nil?
        dates << { type: "published", on: ref_date_str }
      else
        pub_date = Date.strptime pub_date_str.text, "%Y"
        if pub_date.year > ref_date.year
          dates << { type: "published", on: ref_date_str }
          dates << { type: "updated", on: pub_date_str.text }
        else
          dates << { type: "published", on: pub_date_str.text }
        end
      end
      dates
    end

    def fetch_contributors
      id.sub(/\s.*/, "").split("/").reduce([]) do |mem, abbrev|
        publisher = PUBLISHERS[abbrev]
        next mem unless publisher

        publisher[:abbreviation] = abbrev
        mem << { entity: publisher, role: [type: "publisher"] }
      end
    end

    # Fetch ICS.
    # @return [Array<Hash>]
    def fetch_ics
      ics = @doc.xpath("//div[contains(., 'ICS')]/following-sibling::span/a").map do |i|
        code = i.text.match(/[\d.]+/).to_s.split "."
        { field: code[0], group: code[1], subgroup: code[2] }
      end
      @errors[:ics] &&= ics.empty?
      ics
    end

    #
    # Fetch links.
    #
    # @param url [String] document url
    #
    # @return [Array<Hash>]
    #
    def fetch_link(url) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength
      links = [{ type: "src", content: url }]
      obp = @doc.at("//a[.='Read sample']")
      @errors[:link_obp] &&= obp.nil?
      links << { type: "obp", content: obp[:href] } if obp
      rss = @doc.at("//a[contains(@href, 'rss')]")
      @errors[:link_rss] &&= rss.nil?
      links << { type: "rss", content: DOMAIN + rss[:href] } if rss
      pub = @doc.at "//p[contains(., 'publicly available')]/a",
                    "//p[contains(., 'can be downloaded from the')]/a"
      @errors[:link_pub] &&= pub.nil?
      links << { type: "pub", content: pub[:href] } if pub
      links
    end

    # Fetch copyright.
    # @return [Array<Hash>]
    def fetch_copyright # rubocop:disable Metrics/MethodLength
      ref = item_ref @doc
      owner_name = ref.match(/.*?(?=\s)/).to_s
      from = ref.match(/(?<=:)\d{4}/).to_s
      if from.empty?
        date = @doc.at(
          "//span[@itemprop='releaseDate']",
          "//ul[@id='stages']/li[contains(@class,'active')]/ul/li[@class='active']/a/span[@class='stage-date']",
        )
        from = date.text.match(/\d{4}/).to_s
      end
      [{ owner: [{ name: owner_name }], from: from }]
    end
  end
end
