# frozen_string_literal: true

require 'isobib/organization'

module Isobib
  # ISO project group.
  class IsoProjectGroup < Organization
    # @return [Isobib::IsoSubgroup]
    attr_reader :technical_committe

    # @return [IIsobib::soSubgroup]
    attr_reader :subcomitte

    # @return [IIsobib::soSubgroup]
    attr_reader :workgroup

    # @return [String]
    attr_reader :secretariat

    # @param name [String]
    # @param url [String]
    # @param technical_commite [Hash]
    def initialize(name:, url:, technical_committee:)
      super name: name, uri: URI(url)
      @technical_committe = IsoSubgroup.new(technical_committee)
    end
  end

  # ISO subgroup.
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
