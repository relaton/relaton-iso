# frozen_string_literal: true

require "algolia"
require "relaton_iso/hit"

module RelatonIso
  # Page of hit collection.
  class HitCollection < RelatonBib::HitCollection
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # @param text [String] reference to search
    def initialize(text)
      super
      @array = text.match?(/^ISO\sTC\s184\/SC\s?4/) ? fetch_github : fetch_iso
    end

    # @param lang [String, NilClass]
    # @return [RelatonIsoBib::IsoBibliographicItem]
    def to_all_parts(lang = nil) # rubocop:disable Metrics/CyclomaticComplexity
      # parts = @array.reject { |h| h.hit["docPart"]&.empty? }
      hit = @array.min_by do |h|
        IsoBibliography.ref_components(h.hit[:title])[1].to_i
      end
      return @array.first.fetch lang unless hit

      bibitem = hit.fetch lang
      all_parts_item = bibitem.to_all_parts
      @array.reject { |h| h.hit[:uuid] == hit.hit[:uuid] }.each do |hi|
        %r{^(?<fr>ISO(?:\s|/)[^-/:()]+(?:-[\w-]+)?(?::\d{4})?
          (?:/\w+(?:\s\w+)?\s\d+(?:\d{4})?)?)}x =~ hi.hit[:title]
        isobib = RelatonIsoBib::IsoBibliographicItem.new(
          formattedref: RelatonBib::FormattedRef.new(content: fr),
        )
        all_parts_item.relation << RelatonBib::DocumentRelation.new(
          type: "instance", bibitem: isobib,
        )
      end
      all_parts_item
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private

    #
    # Fetch document from GitHub repository
    #
    # @return [Array<RelatonIso::Hit]
    #
    def fetch_github # rubocop:disable Metrics/AbcSize
      ref = text.gsub(/[\s\/]/, "_").upcase
      url = "https://raw.githubusercontent.com/relaton/relaton-data-iso/main/data/#{ref}.yaml"
      resp = Net::HTTP.get_response URI(url)
      return [] unless resp.code == "200"

      hash = YAML.safe_load resp.body
      bib_hash = RelatonIsoBib::HashConverter.hash_to_bib hash
      bib = RelatonIsoBib::IsoBibliographicItem.new(**bib_hash)
      hit = Hit.new({ title: text }, self)
      hit.fetch = bib
      [hit]
    end

    #
    # Fetch hits from iso.org
    #
    # @return [Array<RelatonIso::Hit>]
    #
    def fetch_iso # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      # %r{\s(?<num>\d+)(?:-(?<part>[\d-]+))?} =~ text
      # http = Net::HTTP.new "www.iso.org", 443
      # http.use_ssl = true
      # search = ["status=ENT_ACTIVE,ENT_PROGRESS,ENT_INACTIVE,ENT_DELETED"]
      # search << "docNumber=#{num}"
      # search << "docPartNo=#{part}" if part
      # q = search.join "&"
      # resp = http.get("/cms/render/live/en/sites/isoorg.advancedSearch.do?#{q}",
      #                 "Accept" => "application/json, text/plain, */*")
      config = Algolia::Search::Config.new(application_id: "JCL49WV5AR", api_key: "dd1b9e1ab383f4d4817d29cd5e96d3f0")
      client = Algolia::Search::Client.new config, logger: ::Logger.new($stderr)
      index = client.init_index "all_en"
      resp = index.search text, hitsPerPage: 100, filters: "category:standard"
      # return [] if resp.body.empty?

      # json = JSON.parse resp.body
      # json["standards"]
      resp[:hits].map { |h| Hit.new h, self }.sort! do |a, b|
        if a.sort_weight == b.sort_weight
          # (parse_date(b.hit) - parse_date(a.hit)).to_i
          b.hit[:year] - a.hit[:year]
        else
          a.sort_weight - b.sort_weight
        end
      end
    end

    # @param hit [Hash]
    # @return [Date]
    # def parse_date(hit)
    #   if hit["publicationDate"]
    #     Date.strptime(hit["publicationDate"], "%Y-%m")
    #   elsif %r{:(?<year>\d{4})} =~ hit["docRef"]
    #     Date.strptime(year, "%Y")
    #   elsif hit["newProjectDate"]
    #     Date.parse hit["newProjectDate"]
    #   else
    #     Date.new 0
    #   end
    # end
  end
end
