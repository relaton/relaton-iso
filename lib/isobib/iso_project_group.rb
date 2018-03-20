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

    # @param name [String]
    # @param url [String]
    # @param technical_commite [Hash]
    def initialize(name:, url:, technical_committee:)
      super name: name, uri: URI(url)
      @technical_committe = IsoSubgroup.new(technical_committee)
    end
  end

  class IsoSubgroup
    # @return [String]
    attr_reader :type

    # @return [Integer]
    attr_reader :number

    # @return [String]
    attr_reader :name

    # @param name [String]
    # @param type [String]
    # @param number [Integer]
    def initialize(name:, type:, number:)
      @name   = name
      @type   = type
      @number = number
    end
  end
end