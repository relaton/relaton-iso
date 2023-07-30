module RelatonIso
  module Logger
    extend self

    def method_missing(method, *args, &block)
      Config.configuration.logger.send(method, *args, &block)
    end

    def respond_to_missing?(method_name, include_private = false)
      Config.configuration.logger.respond_to?(method_name) || super
    end
  end
end
