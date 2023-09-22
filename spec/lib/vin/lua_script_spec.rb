# frozen_string_literal: true

require "spec_helper"
include DummyData

describe VIN::LuaScript do
  let(:logical_shard_id_range) { random_logical_shard_id_range }
  let(:config) { VIN::Config.new(logical_shard_id_range: logical_shard_id_range) }

  before { described_class.reset_cache }

  it "replaces ERB tags" do
    expect(described_class.generate_file(config: config)).not_to(match(/<%.*%>/))
  end

  it "sets values from Ruby" do
    lua_script = described_class.generate_file(config: config)
    expect(lua_script).to(match("max_sequence = #{config.max_sequence}"))
    expect(lua_script).to(match("logical_shard_id_min = #{config.logical_shard_id_range.min}"))
    expect(lua_script).to(match("logical_shard_id_max = #{config.logical_shard_id_range.max}"))
  end
end
