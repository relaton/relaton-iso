# frozen_string_literal: true

require "relaton_iso/version"
require "relaton_iso/iso_bibliography"
require "digest/md5"

# if defined? Relaton
#   require "relaton_iso/processor"
#   # don't register the gem if it's required form relaton's registry
#   return if caller.detect { |c| c.include? "register_gems" }

#   Relaton::Registry.instance.register(RelatonIso::Processor)
# end

module RelatonIso
  # Returns hash of XML reammar
  def self.grammar_hash
    gem_path = Gem.loaded_specs["relaton-iso-bib"].full_gem_path
    grammars_path = File.join gem_path, "grammars", "*"
    grammars = Dir[grammars_path].map { |gp| File.read gp }.join
    Digest::MD5.hexdigest grammars
  end
end