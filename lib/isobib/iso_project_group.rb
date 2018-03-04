require 'isobib/organization'

module Isobib
  class IsoProjectGroup < Organization
    # @return [IsoSubgroup]
    attr_accessor :technical_committe

    # @return [IsoSubgroup]
    attr_accessor :subcomitte

    # @return [IsoSubgroup]
    attr_accessor :workgroup

    # @return [String]
    attr_accessor :secretariat

    def initialize(name, technical_committe)
      super name
      @technical_committe = technical_committe
    end
  end

  class IsoSubgroup
    # @return [String]
    attr_accessor :type

    # @return [Integer]
    attr_accessor :number

    # @return [String]
    attr_accessor :name

    def initialize(name)
      @name = name
    end
  end
end