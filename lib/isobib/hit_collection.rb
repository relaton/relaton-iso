require "isobib/hit"

module Isobib
  class HitCollection < Array

    # @return [TrueClass, FalseClass]
    attr_reader :fetched

    # @param hits [Array<Hash>]
    def initialize(hits)
      concat hits.map { |h| Hit.new h }
      @fetched = false
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
  end
end