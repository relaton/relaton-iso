# frozen_string_literal: true

require "forwardable"
require "relaton_iso/hit"

module RelatonIso
  # Page of hit collection.
  class HitCollection
    extend Forwardable

    def_delegators :@array, :<<, :[], :first, :empty?, :any?, :size

    # @return [TrueClass, FalseClass]
    # attr_reader :fetched

    # @return [RelatonIso::HitPages]
    # attr_reader :hit_pages

    # @return [String]
    attr_reader :text

    # @param hits [Array<Hash>]
    def initialize(text)
      @array = []
      @text = text
      %r{(?<num>\d+)(-(?<part>\d+))?} =~ text
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
      @array = json["standards"].map { |h| Hit.new h, self }.sort! do |a, b|
        if a.sort_weight == b.sort_weight
          (parse_date(b.hit) - parse_date(a.hit)).to_i
        else
          a.sort_weight - b.sort_weight
        end
      end
    end

    def select(&block)
      me = DeepClone.clone self
      me.instance_variable_get(:@array).select!(&block)
      me
    end

    def reduce!(sum, &block)
      @array = @array.reduce sum, &block
      self
    end

    # @return [RelatonIso::HitCollection]
    # def fetch
    #   return self if @fetched

    #   workers = RelatonBib::WorkersPool.new 4
    #   workers.worker(&:fetch)
    #   @array.each do |hit|
    #     workers << hit
    #   end
    #   workers.end
    #   workers.result
    #   @fetched = true
    #   self
    # end

    def to_all_parts
      parts = @array.select { |h| !h.hit["docPart"].empty? }
      hit = parts.min_by { |h| h.hit["docPart"].to_i }
      return @array.first.fetch unless hit

      bibitem = hit.fetch
      bibitem.to_all_parts
      parts.reject { |h| h.hit["docRef"] == hit.hit["docRef"] }.each do |hi|
        isobib = RelatonIsoBib::IsoBibliographicItem.new(
          formattedref: RelatonBib::FormattedRef.new(content: hi.hit["docRef"]),
        )
        bibitem.relation << RelatonBib::DocumentRelation.new(
          type: "instance", bibitem: isobib,
        )
      end
      bibitem
    end

    def to_s
      inspect
    end

    def inspect
      "<#{self.class}:#{format('%#.14x', object_id << 1)} @ref=#{@text}>"
    end

    def to_xml(**opts)
      builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.documents do
          @array.each do |hit|
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
