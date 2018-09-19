require "relaton/processor"

module Relaton
  module Isobib
    class Processor < Relaton::Processor

      def initialize
        @short = :isobib
        @prefix = "ISO"
        @defaultprefix = %r{^(ISO)[ /]}
        @idtype = "ISO"
      end

      def get(code, date, opts)
        ::Isobib::IsoBibliography.get(code, date, opts)
      end
    end
  end
end
