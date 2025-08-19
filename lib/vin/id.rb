class VIN
  class Id
    attr_reader :id, :config

    def initialize(id:, config: nil)
      @id = id
      @config = config || VIN::Config.new
    end

    def custom_timestamp
      (id & timestamp_map) >> config.timestamp_shift
    end

    def timestamp
      @timestamp ||= Timestamp.new(custom_timestamp, epoch: config.custom_epoch)
    end

    def logical_shard_id
      (id & logical_shard_id_map) >> config.logical_shard_id_shift
    end

    def data_type
      (id & data_type_map) >> config.data_type_shift
    end

    def sequence
      (id & sequence_map) >> config.sequence_shift
    end

    private

    def sequence_map
      ~(-1 << config.sequence_bits) << config.sequence_shift
    end

    def data_type_map
      ~(-1 << config.data_type_bits) << config.data_type_shift
    end

    def logical_shard_id_map
      (~(-1 << config.logical_shard_id_bits)) << config.logical_shard_id_shift
    end

    def timestamp_map
      ~(-1 << config.timestamp_bits) << config.timestamp_shift
    end
  end
end
