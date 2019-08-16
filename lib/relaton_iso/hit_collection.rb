# frozen_string_literal: true

require "relaton_iso/hit"

module RelatonIso
  # Page of hit collection.
  class HitCollection < Array
    # @return [TrueClass, FalseClass]
    # attr_reader :fetched

    # @return [RelatonIso::HitPages]
    # attr_reader :hit_pages

    # @return [String]
    attr_reader :ref

    # @param hits [Array<Hash>]
    def initialize(ref)
      # concat(hits.map { |h| Hit.new(h, self) })
      # @fetched = false
      # @hit_pages = hit_pages
      @ref = ref
      %r{(?<num>\d+)(-(?<part>\d+))?} =~ ref
      http = Net::HTTP.new "www.iso.org", 443
      http.use_ssl = true
      search = ["status=ENT_ACTIVE,ENT_PROGRESS,ENT_INACTIVE,ENT_DELETED"]
      search << "docNumber=#{num}"
      search << "docPartNo=#{part}" if part
      q = search.join "&"
      resp = http.get("/cms/render/live/en/sites/isoorg.advancedSearch.do?#{q}",
        "Accept" => "application/json, text/plain, */*")
      return if resp.body.empty?

      json = JSON.parse resp.body
      concat(json["standards"].map { |h| Hit.new h, self })
      sort! do |a, b|
        if a.sort_weight == b.sort_weight
          (parse_date(b.hit) - parse_date(a.hit)).to_i
        else
          a.sort_weight - b.sort_weight
        end
      end
    end

    def to_s
      inspect
    end

    def inspect
      "<#{self.class}:#{format('%#.14x', object_id << 1)} @ref=#{@ref}>"
    end

    def to_xml(**opts)
      builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.documents do
          each do |hit|
            hit.fetch
            hit.to_xml xml, **opts
          end
        end
      end
      builder.to_xml
    end

    private

    def parse_date(hit)
      if hit["publicationDate"]
        Date.strptime(hit["publicationDate"], "%Y-%m")
      elsif %r{:(?<year>\d{4})} =~ hit["docRef"]
        Date.strptime(year, "%Y")
      elsif hit["newProjectDate"]
        Date.parse hit["newProjectDate"]
      else
        Date.new 0
      end
    end
  end
end
