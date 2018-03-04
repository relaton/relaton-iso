module Isobib
  module ContributorRoleTypes
    AUTHOR        = 'author'
    EDITOR        = 'editor'
    CARETIGRAPHER = 'cartographer'
    PUBLISHER     = 'publisher'
  end

  class ContributorRole

    # @return [FormattedString]
    attr_accessor :description

    # @return [Array<ContributorRoleType>]
    attr_accessor :type

    def initialize(type)
      @type = type
      @description = []
    end
  end

  class ContributionInfo

    # @return [Array<ContributorRole>]
    attr_accessor :role

    # @return [Contributor]
    attr_accessor :entity

    def initialize(entity)
      @entity = entity
      @role   = []
    end
  end
end