# frozen_string_literal: true

require 'isobib/version'
require 'isobib/iso_bibliography'
if defined? Relaton
  require_relative 'relaton/processor'
  Relaton::Registry.instance.register(Relaton::Isobib::Processor)
end
