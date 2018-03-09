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

    # @param type [OrgIdentifierType]
    # @param value [String]
    def initialize(type, value)
      @type  = type
      @value = value
    end
  end

  class Organization < Contributor
    # @return [LocalizedString]
    attr_reader :name

    # @return [Array<OrgIdentifier>]
    attr_accessor :identifiers

    # @param name [String]
    # @param uri [URI]
    def initialize(name:, uri: nil)
      super(uri)
      @name = LocalizedString.new(name)
      @identifiers = []
    end
  end
end