# frozen_string_literal: true

# Isobib module
module Isobib
  # Contributor's role.
  class ContributorRole
    # @return [Array<FormattedString>]
    attr_reader :description

    # @return [ContributorRoleType]
    attr_reader :type

    # @param type [ContributorRoleType] allowed types "author", "editor",
    #   "cartographer", "publisher"
    def initialize(type, description = [])
      @type = type
      @description = description.map { |d| FormattedString.new d }
    end

    def to_xml(builder)
      builder.role(type: type) do
        description.each do |d|
          builder.description do |desc|
            d.to_xml(desc)
          end
        end
      end
    end
  end

  # Contribution info.
  class ContributionInfo
    # @return [Array<ContributorRole>]
    attr_reader :role

    # @return
    #   [Isobib::Person, Isosbib::Organization, Isosbib::IsoProjectGroup]
    attr_reader :entity

    # @param entity
    #   [Isobib::Person, Isobib::Organization, Isobib::IsoProjectGroup]
    # @param role [Array<String>]
    def initialize(entity:, role: ['publisher'])
      @entity = entity
      @role   = role.map { |r| ContributorRole.new(r) }
    end

    def to_xml(builder)
      builder.contributor do
        role.each { |r| r.to_xml builder }
        entity.to_xml builder
      end
    end
  end
end
