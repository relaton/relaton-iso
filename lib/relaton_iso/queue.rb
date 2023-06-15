module RelatonIso
  #
  # Queue of links to fetch.
  #
  class Queue
    extend Forwardable
    def_delegator :queue, :[]

    FILE = "iso-queue.txt".freeze

    #
    # Open queue file if exist. If not, create new empty queue.
    #
    # @return [Array<String>] queue
    #
    def queue
      @queue ||= File.exist?(FILE) ? File.read(FILE).split("\n") : []
    end

    #
    # Add item to queue at first position if it is not already there.
    #
    # @param [String] item item to add
    #
    # @return [void]
    #
    def add_first(item)
      queue.unshift item unless queue.include? item
    end

    #
    # Move or add item to the end of the queue.
    #
    # @param [String] item item to move or add
    #
    # @return [void]
    #
    def move_last(item)
      queue.delete item
      queue << item
    end

    #
    # Take first item from the queue.
    #
    # @return [String] an item
    #
    # def take_first
    #   queue.shift
    # end

    #
    # Save queue to file.
    #
    # @return [void]
    #
    def save
      File.write FILE, queue.to_a.join("\n")
    end
  end
end
