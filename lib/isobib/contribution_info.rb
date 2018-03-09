module Isobib
  module ContributorRoleTypes
    AUTHOR        = 'author'
    EDITOR        = 'editor'
    CARETIGRAPHER = 'cartographer'
    PUBLISHER     = 'publisher'
  end

  class ContributorRole

    # @return [Array<FormattedString>]
    attr_accessor :description

    # @return [ContributorRoleType]
    attr_reader :type

    # @param type [ContributorRoleType]
    def initialize(type)
      @type = type
      @description = []
    end
  end

  class ContributionInfo

    # @return [Array<ContributorRole>]
    attr_accessor :role

    # @return [Contributor, Organization, IsoProjectGroup]
    attr_accessor :entity

    # @param entity [Contributor, Organization, IsoProjectGroup]
    # @param role [Array<String>]
    def initialize(entity:, role: [])
      @entity = entity
      @role   = role.map{ |r| ContributorRole.new(r) }
    end
  end
end