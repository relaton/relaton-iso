require "algoliasearch"
require "isobib/hit_collection"

module Isobib
  class HitPages < Array
    Algolia.init application_id: "JCL49WV5AR", api_key: "dd1b9e1ab383f4d4817d29cd5e96d3f0"

    # @param text [String]
    def initialize(text)
      @text = text
      @index = Algolia::Index.new "all_en"
      resp = @index.search(text, facetFilters: ["category:standard"]) 
      # @nb_hits = resp["nbHits"]
      @nb_pages = resp["nbPages"]
      # @hits_per_page = resp["hitsPerPage"]
      self << HitCollection.new(resp["hits"])
    end

    # @return [Isobib::HitCollection]
    def last
      collections[@nb_pages - 1]
    end

    # @param i [Integer]
    # @return [Isobib::HitCollection]
    def [](i)
      # collection i
      return if i + 1 > @nb_pages
      while Array.instance_method(:size).bind(self).call < i + 1
        resp = @index.search(@text, facetFilters: ["category:standard"], page: i) 
        self << HitCollection.new(resp["hits"])
      end
      super
    end

    # @return [Array]
    def map(&block)
      m = []
      @nb_pages.times do |n|
        m << yield(self[n])
      end
      m
    end

    def each(&block)
      @nb_pages.times do |n|
        yield self[n]
      end
    end

    # @return [Integer]
    def size
      @nb_pages
    end

    private

    # @param i [Integer]
    # @return [Isobib::HitCollection]
    def collection(i)
      return if i + 1 > @nb_pages
      while size < i + 1
        resp = @index.search(@text, facetFilters: ["category:standard"], page: i) 
        self << HitCollection.new(resp["hits"])
      end
      self[i]
    end
  end
end