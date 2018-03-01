module Isobib
  class IsoProjectGroup
    attr_accessor :technical_committe, :subcomitte, :workgroup, :secretariat,
      :iso_bibliographic_item

    # technical_commite - IsoSubgroup
    def initialize(technical_committe)
      @technical_committe = technical_committe
    end
  end

  class IsoSubgroup
    attr_accessor :type, :number, :name, :iso_project_group

    def initialize(name)
      @name = name
    end
  end
end