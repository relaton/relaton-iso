require 'isobib/contributor'

module Isobib
  module OrgIdentifierType
    ORCID = 'orcid'
    URI   = 'uri'
  end

  class OrgIdentifier
    # @return [OrgIdentifierType]
    attr_accessor :type

    # @return [String]
    attr_accessor :value

    def initialize(type, value)
      @type  = type
      @value = value
    end
  end

  class Organization < Contributor
    # @return [LocalizedString]
    attr_accessor :name

    # @return [Array<OrgIdentifier>]
    attr_accessor :identifiers

    def initialize(name)
      super()
      @name = name
      @identifiers = []
    end
  end
end