# frozen_string_literal: true

class VIN
  class Config
    # Expressed in milliseconds.
    attr_reader :custom_epoch

    # For instance, 40 bits gives us 1099511627776 milliseconds, or 34.8 years. Enough time to last us until 2057, enough time for any of us to retire.
    attr_reader :timestamp_bits

    # For instance, 3 bits gives us 8 logical shards, which means we can have 8 different servers generating ids.
    attr_reader :logical_shard_id_bits

    # For instance, 9 bits gives us 512 different data types.
    attr_reader :data_type_bits

    # For instance, 11 bits gives us 2048 ids per millisecond per logical shard.
    attr_reader :sequence_bits

    # Defaults to allowing all logical shard ids to be generated by this server.
    attr_reader :logical_shard_id_range

    def initialize(
      custom_epoch: nil,
      timestamp_bits: nil,
      logical_shard_id_bits: nil,
      data_type_bits: nil,
      sequence_bits: nil,
      logical_shard_id_range: nil
    )
      @custom_epoch = custom_epoch || ENV.fetch("VIN_CUSTOM_EPOCH").to_i
      @timestamp_bits = timestamp_bits || ENV.fetch("VIN_TIMESTAMP_BITS").to_i
      @logical_shard_id_bits = logical_shard_id_bits || ENV.fetch("VIN_LOGICAL_SHARD_ID_BITS").to_i
      @data_type_bits = data_type_bits || ENV.fetch("VIN_DATA_TYPE_BITS").to_i
      @sequence_bits = sequence_bits || ENV.fetch("VIN_SEQUENCE_BITS").to_i
      @logical_shard_id_range = logical_shard_id_range || fetch_allowed_range!
    end

    def min_logical_shard_id
      0
    end

    def max_logical_shard_id
      @max_logical_shard_id ||= ~(-1 << logical_shard_id_bits)
    end

    def logical_shard_id_allowed_range
      @logical_shard_id_allowed_range ||= (min_logical_shard_id..max_logical_shard_id)
    end

    def min_data_type
      0
    end

    def max_data_type
      @max_data_type ||= ~(-1 << data_type_bits)
    end

    def data_type_allowed_range
      @data_type_allowed_range ||= (min_data_type..max_data_type)
    end

    def max_sequence
      @max_sequence ||= ~(-1 << sequence_bits)
    end

    def sequence_shift
      0
    end

    def data_type_shift
      @data_type_shift ||= sequence_bits
    end

    def logical_shard_id_shift
      @logical_shard_id_shift ||= (sequence_bits + data_type_bits)
    end

    def timestamp_shift
      @timestamp_shift ||= (sequence_bits + data_type_bits + logical_shard_id_bits)
    end

    def fetch_allowed_range!
      range = Range.new(
        ENV.fetch("VIN_LOGICAL_SHARD_ID_RANGE_MIN", logical_shard_id_allowed_range.min).to_i,
        ENV.fetch("VIN_LOGICAL_SHARD_ID_RANGE_MAX", logical_shard_id_allowed_range.max).to_i,
      )
      unless (logical_shard_id_allowed_range.to_a & range.to_a) == range.to_a
        raise ArgumentError, "VIN_LOGICAL_SHARD_ID_RANGE_MIN and VIN_LOGICAL_SHARD_ID_RANGE_MAX env vars compose a range outside the allowed range of #{logical_shard_id_allowed_range} defined by the number of bits in VIN_LOGICAL_SHARD_ID_BITS env var."
      end
      range
    end
  end
end