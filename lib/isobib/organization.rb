# frozen_string_literal: true

require 'isobib/contributor'

module Isobib
  module OrgIdentifierType
    ORCID = 'orcid'
    URI   = 'uri'
  end

  # Organization identifier.
  class OrgIdentifier
    # @return [Isobib::OrgIdentifierType]
    attr_reader :type

    # @return [String]
    attr_reader :value

    # @param type [Isobib::OrgIdentifierType]
    # @param value [String]
    def initialize(type, value)
      @type  = type
      @value = value
    end

    def to_xml(builder)
      builder.identifier(value, type: type)
    end
  end

  # Organization.
  class Organization < Contributor
    # @return [Isobib::LocalizedString]
    attr_reader :name

    # @return [Isobib::LocalizedString]
    attr_reader :abbreviation

    # @return [Array<Isobib::OrgIdentifier>]
    attr_reader :identifiers

    # @param name [String]
    # @param abbreviation [String]
    # @param url [String]
    def initialize(name:, abbreviation: nil, url: nil)
      super(url)
      @name         = LocalizedString.new name
      @abbreviation = LocalizedString.new abbreviation
      @identifiers  = []
    end

    # rubocop:disable Metrics/AbcSize
    # @return [String]
    def to_xml(builder)
      builder.organization do
        builder.name { |b| name.to_xml b }
        builder.abbreviation { |a| abbreviation.to_xml a } if abbreviation
        builder.uri uri.to_s if uri
        identifiers.each { |identifier| identifier.to_xml builder }
        super
      end
    end
    # rubocop:enable Metrics/AbcSize
  end
end
