module DummyData
  def dummy_config
    @dummy_config ||= VIN::Config.new
  end

  def random_logical_shard_id
    rand(dummy_config.min_logical_shard_id..dummy_config.max_logical_shard_id)
  end

  def random_logical_shard_id_range
    min = random_logical_shard_id
    min..rand(min..dummy_config.max_logical_shard_id)
  end

  def random_data_type
    rand(0..~(-1 << dummy_config.data_type_bits))
  end

  def dummy_redis_response(count: nil, sequence_start: nil, logical_shard_id: nil, now: nil)
    count ||= 1
    logical_shard_id ||= random_logical_shard_id
    now ||= Time.now
    @sequence = (sequence_start - 1) unless sequence_start.nil?
    @sequence = -1 if @sequence.nil? || @sequence >= dummy_config.max_sequence
    @sequence += count
    start_sequence = @sequence - count + 1
    @sequence = dummy_config.max_sequence if @sequence >= dummy_config.max_sequence
    [
      start_sequence,
      @sequence,
      logical_shard_id,
      now.to_i,
      now.usec,
    ]
  end

  def dummy_id(sequence: nil, data_type: nil, logical_shard_id: nil, now: nil)
    sequence ||= 0
    data_type ||= random_data_type
    logical_shard_id ||= random_logical_shard_id
    now ||= Time.now
    timestamp = VIN::Timestamp.from_redis(now.to_i, now.usec).with_epoch(dummy_config.custom_epoch)
    (
      (timestamp.milliseconds << dummy_config.timestamp_shift) |
      (logical_shard_id << dummy_config.logical_shard_id_shift) |
      (data_type << dummy_config.data_type_shift) |
      (sequence << dummy_config.sequence_shift)
    )
  end
end
