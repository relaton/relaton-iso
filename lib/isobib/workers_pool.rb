require 'thread'

class WorkersPool
  def initialize(num_workers = 2, &block)
    @num_workers = num_workers < 2 ? 2 : num_workers
    @queue = SizedQueue.new(num_workers * 2)
    @result = []
    @threads = num_workers.times.map do
      Thread.new do
        res = []
        until (item = @queue.pop) == :END
          @result << block.call(item)
        end
        res
      end
    end
  end

  def result
    @threads.each(&:join)
    @result
  end

  def <<(item)
    @queue << item
  end

  def end
    @num_workers.times { @queue << :END }
  end

  def size
    @result.size
  end
end