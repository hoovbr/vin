# frozen_string_literal: true

class VIN
  class Request
    include VIN::Mixins::Redis

    MAX_TRIES = 5

    attr_reader :data_type, :count, :config

    def initialize(config, data_type, count = 1)
      raise(ArgumentError, "data_type must be a number") unless data_type.is_a?(Numeric)
      unless config.data_type_allowed_range.include?(data_type)
        raise(ArgumentError, "data_type is outside the allowed range of #{config.data_type_allowed_range}")
      end
      raise(ArgumentError, "count must be a number") unless count.is_a?(Numeric)
      raise(ArgumentError, "count must be greater than zero") unless count.positive?

      @tries = 0
      @data_type = data_type
      @count = count
      @config = config
    end

    def response
      Response.new(try_redis_response)
    end

    private

    def lua_script_sha
      @@lua_script_sha ||= redis.script(:load, LuaScript.generate_file(config: config))
    end

    def lua_keys
      @lua_keys ||= [data_type, count]
    end

    # NOTE: If too many requests come in inside of a millisecond the Lua script
    # will lock for 1ms and throw an error. This is meant to retry in those cases.
    def try_redis_response
      @tries += 1
      redis_response
    rescue Redis::CommandError => e
      raise(e) unless @tries < MAX_TRIES

      # Clear out the cache of the Lua script SHA to force a reload. This
      # is necessary after a Redis restart
      @@lua_script_sha = nil

      # Exponentially sleep more and more on each try
      sleep((@tries * @tries).to_f / 900)
      retry
    end

    def redis_response
      @redis_response ||= redis.evalsha(lua_script_sha, keys: lua_keys)
    end
  end
end
