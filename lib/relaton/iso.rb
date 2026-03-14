# frozen_string_literal: true

require "net/http"
require "pubid/iso"
require "relaton/index"
require "isoics"
require "relaton/bib"
require "relaton/core"
require_relative "iso/version"
require_relative "iso/util"
require_relative "iso/item_data"
require_relative "iso/model/item"
require_relative "iso/model/relation"
require_relative "iso/model/bibitem"
require_relative "iso/model/bibdata"
require_relative "iso/hit_collection"
require_relative "iso/bibliography"

module Relaton
  module Iso
    INDEXFILE = "index-v1"

    def self.grammar_hash
      # gem_path = File.expand_path "..", __dir__
      # grammars_path = File.join gem_path, "grammars", "*"
      # grammars = Dir[grammars_path].sort.map { |gp| File.read gp, encoding: "UTF-8" }.join
      Digest::MD5.hexdigest VERSION + Bib::VERSION # grammars
    end
  end
end
