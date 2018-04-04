require "isobib/hit"

module Isobib
  class HitCollection < Array

    # @return [TrueClass, FalseClass]
    attr_reader :fetched

    # @return [Isobib::HitPages]
    attr_reader :hit_pages

    # @param hits [Array<Hash>]
    def initialize(hits, hit_pages = nil)
      concat hits.map { |h| Hit.new(h, self) }
      @fetched = false
      @hit_pages = hit_pages
    end

    # @return [Isobib::HitCollection]
    def fetch
      workers = WorkersPool.new 4 do |hit|
        hit.fetch
      end
      each do |hit|
        workers << hit
      end
      workers.end
      workers.result
      @fetched = true
      self
    end

    def to_s
      inspect
    end

    def inspect
      "<#{self.class}:#{'0x00%x' % (object_id << 1)} @fetched=#{@fetched}>"
    end
  end
end