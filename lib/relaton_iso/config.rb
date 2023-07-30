module RelatonIso
  module Config
    def configure
      yield configuration if block_given?
    end

    def configuration
      @configuration ||= Configuration.new
    end

    extend self
  end

  class Configuration
    attr_accessor :logger

    def initialize
      @logger = ::Logger.new $stderr
      @logger.level = ::Logger::WARN
      @logger.progname = "relaton-iso"
      @logger.formatter = proc do |_severity, _datetime, progname, msg|
        "[#{progname}] #{msg}\n"
      end
    end
  end
end
