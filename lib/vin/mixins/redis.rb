# frozen_string_literal: true

class VIN
  module Mixins
    module Redis
      DEFAULT_REDIS_URL = "redis://127.0.0.1:6379"

      def redis
        # TODO: Redis config for multiple servers
        @redis ||= ::Redis.new(
          url: ENV["VIN_REDIS_URL"] || ENV["REDIS_URL"] || DEFAULT_REDIS_URL,
        )
      end
    end
  end
end
