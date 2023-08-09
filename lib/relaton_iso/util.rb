module RelatonIso
  module Util
    extend RelatonBib::Util

    def self.logger
      RelatonIso.configuration.logger
    end
  end
end
