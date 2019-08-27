# frozen_string_literal: true

require "relaton_iso/version"
require "relaton_iso/iso_bibliography"

# if defined? Relaton
#   require "relaton_iso/processor"
#   # don't register the gem if it's required form relaton's registry
#   return if caller.detect { |c| c.include? "register_gems" }

#   Relaton::Registry.instance.register(RelatonIso::Processor)
# end
