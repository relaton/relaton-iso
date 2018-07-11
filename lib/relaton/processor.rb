require "relaton/processor"

module Relaton
  module Isobib
    class Processor < Relaton::Processor

      def initialize
        @short = :isobib
        @prefix = %r{^(ISO|IEC)[ /]|^IEV($| )}
      end

      def get(code, date, opts)
        ::Isobib::IsoBibliography.get(code, date, opts)
      end
    end
  end
end
