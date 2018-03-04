module Isobib

  class ContactMethod
    # @return [String] @todo TBD
    attr_accessor :contact
  end

  class Affilation
    # @return [LocalizedString]
    attr_accessor :name

    # @return [Array<FormattedString>]
    attr_accessor :description

    # @return [Organization]
    attr_accessor :organization

    def initialize(organization)
      @organization = organization
      @description  = []
    end
  end

  class Contributor
    # @return [URI]
    attr_accessor :uri

    # @return [Array<ContactMethod>]
    attr_accessor :contacts

    def initialize
      @contacts = []
    end
  end
end