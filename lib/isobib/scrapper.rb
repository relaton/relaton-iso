require "algoliasearch"
# require "nokogiri"
# require "net/http"
# require "open-uri"
# require "isobib/workers_pool"
require "isobib/hit"
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
  end
end