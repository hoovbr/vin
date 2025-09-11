require "vin/config"

class VIN
  # rubocop:disable Metrics/ClassLength
  class Generator
    attr_reader :data_type, :count, :config, :custom_timestamp

    def initialize(config:)
      @config = config
    end

    def generate_id(data_type)
      validate_data_type!(data_type)

      generate_single_batch(data_type, 1, nil).first
    end

    def generate_ids(data_type, count)
      validate_data_type!(data_type)
      validate_count!(count)

      generate_single_batch(data_type, count, nil)
    end

    def generate_ids_from_timestamps(data_type, timestamps:)
      validate_data_type!(data_type)
      raise(ArgumentError, "timestamps must be an array") unless timestamps.is_a?(Array)
      raise(ArgumentError, "timestamps array cannot be empty") if timestamps.empty?

      timestamps.each { |ts| validate_timestamp!(ts) }

      # Check for potential duplicate ID issue
      timestamp_counts = timestamps.tally
      max_count = timestamp_counts.values.max
      if max_count > config.max_sequence
        raise ArgumentError,
              "Cannot generate #{max_count} IDs for the same timestamp. " \
              "Maximum allowed is #{config.max_sequence} (2^#{config.sequence_bits} - 1). " \
              "Requesting more would produce duplicate IDs."
      end

      generate_ids_for_multiple_timestamps(data_type, timestamps)
    end

    private

    def validate_data_type!(data_type)
      raise(ArgumentError, "data_type must be an integer") unless data_type.is_a?(Integer)

      return if config.data_type_allowed_range.include?(data_type)
      raise(ArgumentError, "data_type is outside the allowed range of #{config.data_type_allowed_range}")
    end

    def validate_count!(count)
      raise(ArgumentError, "count must be an integer") unless count.is_a?(Integer)
      raise(ArgumentError, "count must be a positive number") if count < 1
    end

    def generate_single_batch(data_type, count, timestamp)
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

    def generate_ids_for_multiple_timestamps(data_type, timestamps)
      # Group timestamps to optimize Redis calls
      # Each unique timestamp needs only one Redis call, then we can reuse sequences
      timestamp_groups = {}
      timestamps.each_with_index do |ts, index|
        timestamp_groups[ts] ||= []
        timestamp_groups[ts] << index
      end

      # Result array to maintain order
      results = Array.new(timestamps.length)

      # Process each unique timestamp
      timestamp_groups.each do |ts, indices|
        needed_count = indices.length
        ids = []

        # The Lua script can't always return as many IDs as you want. So we loop
        # until we have the exact amount.
        while ids.length < needed_count
          @data_type = data_type
          @count = needed_count - ids.length
          @custom_timestamp = ts

          batch_ids = response.sequence.map do |sequence|
            (
              shifted_timestamp |
              shifted_logical_shard_id |
              shifted_data_type |
              (sequence << config.sequence_shift)
            )
          end

          ids += batch_ids
          @response = nil

          # Safety check to prevent infinite loops
          break unless batch_ids.any?
        end

        # Place IDs in correct positions to maintain order
        indices.each_with_index do |original_index, i|
          results[original_index] = ids[i] if i < ids.length
        end
      end

      results
    end

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
  # rubocop:enable Metrics/ClassLength
end
