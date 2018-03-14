require 'uri'

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

    # @param organization [Organization]
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

    # @param uri [URI]
    def initialize(uri = nil)
      @uri = uri
      @contacts = []
    end

    # @return [String]
    def url
      @uri.to_s
    end
  end
end