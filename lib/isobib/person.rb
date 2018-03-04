require 'isobib/contributor'

module Isobib

  class FullName
    # @return [Array<LocalizedString>]
    attr_accessor :forenames

    # @return [Array<LocalizedString]
    attr_accessor :inials

    # @return [LocalizedString]
    attr_accessor :surname

    # @return [Array<LocalizedString]
    attr_accessor :additions

    # @return [Array<LocalizedString]
    attr_accessor :prefix

    def initialize(surname)
      @surname   = surname
      @forenames = []
      @initials  = []
      @additions = []
      @prefix    = []
    end
  end

  module PersonIdentifierType
    ISNI = 'isni'
    URI  = 'uri'
  end

  class PersonIdentifier
    # @return [PersonIdentifierType]
    attr_accessor :type

    # @return [String]
    attr_accessor :value

    def initialize(type, value)
      @type  = type
      @value = value
    end
  end

  class Person < Contributor
    # @return [FullName]
    attr_accessor :name

    # @return [Array<Affilation>]
    attr_accessor :affilation

    # @return [Array<PersonIdentifier>]
    attr_accessor :identifiers

    def initialize
      super
      @affilation = []
      @identifiers = []
    end
  end
end