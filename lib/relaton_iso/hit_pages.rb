# frozen_string_literal: true

require "algoliasearch"
require "relaton_iso/hit_collection"

module RelatonIso
  # Pages of hits.
  class HitPages < Array
    Algolia.init application_id: "JCL49WV5AR",
                 api_key: "dd1b9e1ab383f4d4817d29cd5e96d3f0"

    # @return [String]
    attr_reader :text

    # @param text [String]
    def initialize(text)
      @text = text
      @index = Algolia::Index.new "all_en"
      resp = @index.search(text, facetFilters: ["category:standard"])
      @nb_pages = resp["nbPages"]
      self << HitCollection.new(resp["hits"], self)
    end

    # @return [RelatonIso::HitCollection]
    def last
      collection(@nb_pages - 1)
    end

    # @param i [Integer]
    # @return [RelatonIso::HitCollection]
    def [](idx)
      # collection i
      return if idx + 1 > @nb_pages

      collection idx
      super
    end

    # @return [Array]
    def map(&block)
      m = []
      @nb_pages.times do |n|
        m << yield(self[n]) if block
      end
      m
    end

    def each(&block)
      @nb_pages.times do |n|
        yield self[n] if block
      end
    end

    def to_s
      inspect
    end

    def inspect
      "<#{self.class}:#{format('%#.14x', object_id << 1)} @text=#{@text} "\
      "@pages=#{@nb_pages}>"
    end

    # @return [Integer]
    def size
      @nb_pages
    end

    def to_xml(**opts)
      builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.documents do
          each do |page|
            page.fetch
            page.each { |hit| hit.to_xml xml, **opts }
          end
        end
      end
      builder.to_xml
    end

    private

    # @param i [Integer]
    # @return [RelatonIso::HitCollection]
    def collection(idx)
      return if idx + 1 > @nb_pages

      while Array.instance_method(:size).bind(self).call < idx + 1
        resp = @index.search(@text,
                             facetFilters: ["category:standard"],
                             page: idx)
        self << HitCollection.new(resp["hits"], self)
      end
      Array.instance_method(:[]).bind(self).call idx
    end
  end
end
