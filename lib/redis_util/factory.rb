require 'redis'
require 'redis-namespace'

module RedisUtil

  # A factory class for creating redis connections, useful for
  # reconnecting them after a fork
  #
  class Factory
    include GemLogger::LoggerSupport
    extend MonitorMixin

    class << self

      # Set the path to the yml config file which defines all the redis connections.
      # If running in rails, it will default to "#{Rails.root}/config/redis.yml"
      attr_accessor :config_file

      # Set the environment we are running in (development/test/etc).
      # If running in rails, it will default to Rails.env
      attr_accessor :env

      attr_accessor :clients, :configuration

      # Creates/retrieves a single redis client for the given named configuration
      #
      # @param [Symbol] name The name of the redis configuration (config/redis.yml) to use
      # @return [Redis] A redis client object
      def connect(name)
        conf = lookup_config(name)
        synchronize do
          clients[name] ||= []
          if clients[name].first.nil?
            clients[name] << new_redis_client(conf)
          end
        end
        clients[name].first
      end

      # Always create and return a new redis client for the given named configuration
      #
      # @param [Symbol] name The name of the redis configuration (config/redis.yml) to use
      # @return [Redis] A redis client object
      def create(name)
        conf = lookup_config(name)
        synchronize do
          clients[name] ||= []
          clients[name] << new_redis_client(conf)
        end
        clients[name].last
      end

      # Disconnect all known redis clients
      #
      # @param [Symbol] key (optional, defaults to all) The name of the redis configuration (config/redis.yml) to disconnect
      def disconnect(key=nil)
        logger.debug "RedisUtil::Factory.disconnect start"
        synchronize do
          clients.clone.each do |name, client|
            next if key && name != key

            connections = clients.delete(name) || []
            connections.each do |connection|
              begin
                logger.debug "Disconnecting Redis client: #{connection}"
                connection.quit
              rescue => e
                logger.warn("Exception while disconnecting: #{e}")
              end
            end
          end
        end
        logger.debug "RedisUtil::Factory.disconnect complete"
        nil
      end

      # Reconnect all known redis clients
      #
      # @param [Symbol] key (optional, defaults to all) The name of the redis configuration (config/redis.yml) to reconnect
      def reconnect(key=nil)
        logger.debug "RedisUtil::Factory.reconnect start"
        synchronize do
          clients.each do |name, connections|
            next if key && name != key

            connections.each do |connection|
              logger.debug "Reconnecting Redis client: #{connection}"
              retry_count = 0
              begin
                connection.client.reconnect
              rescue => e
                if retry_count < 3
                  sleep(Random.rand(5))
                  retry_count += 1
                  retry
                end
              end
            end
          end
        end
        logger.debug "RedisUtil::Factory.reconnect complete"
      end

      def configuration
        synchronize do
          @configuration ||= begin

            if config_file.nil? || env.nil?
              if defined?(Rails)
                self.config_file ||= "#{Rails.root}/config/redis.yml"
                self.env ||= Rails.env.to_s
              else
                raise "You need to initialize with an env and config file"
              end
            end

            self.clients = {}
            require 'erb'
            config = YAML::load(ERB.new(IO.read(config_file)).result)
            symbolize(config[env])
          end
        end
      end

      private

      def lookup_config(name)
        conf = configuration[name]
        raise "No redis configuration for #{env} environment in redis.yml for #{name}" unless conf
        conf
      end

      def new_redis_client(conf)
        redis = ::Redis.new(conf)
        if conf[:namespace]
          redis = Redis::Namespace.new(conf[:namespace].to_sym, :redis => redis)
        end
        redis
      end

      def symbolize(hash)
        hash.inject({}) do |options, (key, value)|
          value = symbolize(value) if value.kind_of?(Hash)
          options[key.to_sym || key] = value
          options
        end
      end

    end

  end

end
