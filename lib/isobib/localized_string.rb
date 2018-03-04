module Isobib
  class LocalizedString
    # @return [Array<String>] language Iso639 code
    attr_accessor :language

    # @return [Array<String>] script Iso15924 code
    attr_accessor :script

    # @return [String]
    attr_accessor :content

    def initialize(content)
      @language = []
      @script   = []
      @content  = content
    end
  end
end