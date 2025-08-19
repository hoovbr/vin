require "vin/config"

class VIN
  class Generator
    attr_reader :data_type, :count, :config, :custom_timestamp

    def initialize(config:)
      @config = config
    end

    def generate_ids(data_type, count = 1, timestamp: nil)
      raise(ArgumentError, "data_type must be an integer") unless data_type.is_a?(Integer)

      unless config.data_type_allowed_range.include?(data_type)
        raise(ArgumentError, "data_type is outside the allowed range of #{config.data_type_allowed_range}")
      end

      raise(ArgumentError, "count must be an integer") unless count.is_a?(Integer)
      raise(ArgumentError, "count must be a positive number") if count < 1

      if timestamp
        validate_timestamp!(timestamp)
      end

      @data_type = data_type
      @count = count
      @custom_timestamp = timestamp

      result = response.sequence.map do |sequence|
        (
          shifted_timestamp |
          shifted_logical_shard_id |
          shifted_data_type |
          (sequence << config.sequence_shift)
        )
      end
      # After generating a batch of IDs, we reset the response object so that it generates new IDs later with a new request.
      @response = nil
      result
    end

    private

    def shifted_timestamp
      timestamp = if custom_timestamp
        # Custom timestamp is in Unix milliseconds (absolute time)
        # Convert it to be relative to custom epoch
        milliseconds_from_custom_epoch = custom_timestamp - config.custom_epoch
        Timestamp.new(milliseconds_from_custom_epoch, epoch: config.custom_epoch)
      else
        Timestamp.from_redis(response.seconds, response.microseconds_part)
      end
      timestamp.with_epoch(config.custom_epoch).milliseconds << config.timestamp_shift
    end

    def validate_timestamp!(timestamp)
      raise(ArgumentError, "timestamp must be an integer (milliseconds)") unless timestamp.is_a?(Integer)
      raise(ArgumentError, "timestamp cannot be before the custom epoch (#{config.custom_epoch}ms since Unix epoch)") if timestamp < config.custom_epoch
    end

    def shifted_data_type
      data_type << config.data_type_shift
    end

    def shifted_logical_shard_id
      response.logical_shard_id << config.logical_shard_id_shift
    end

    def response
      @response ||= Request.new(config, data_type, count, custom_timestamp: custom_timestamp).response
    end
  end
end
