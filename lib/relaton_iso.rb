# frozen_string_literal: true

require "relaton_iso/version"
require "relaton_iso/iso_bibliography"
if defined? Relaton
  require_relative "relaton/processor"
  Relaton::Registry.instance.register(Relaton::RelatonIso::Processor)
end
