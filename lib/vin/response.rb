# frozen_string_literal: true

class VIN
  class Response
    START_SEQUENCE_INDEX = 0
    END_SEQUENCE_INDEX = 1
    LOGICAL_SHARD_ID_INDEX = 2
    SECONDS_INDEX = 3
    MICROSECONDS_INDEX = 4

    def initialize(redis_response)
      @redis_response = redis_response
    end

    def sequence
      start_sequence..end_sequence
    end

    def start_sequence
      redis_response[START_SEQUENCE_INDEX]
    end

    def end_sequence
      redis_response[END_SEQUENCE_INDEX]
    end

    def logical_shard_id
      redis_response[LOGICAL_SHARD_ID_INDEX]
    end

    def seconds
      redis_response[SECONDS_INDEX]
    end

    def microseconds_part
      redis_response[MICROSECONDS_INDEX]
    end

    private

    attr_reader :redis_response
  end
end
