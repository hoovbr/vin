# frozen_string_literal: true

require "redis"
require "vin/mixins/redis"

class VIN
  extend VIN::Mixins::Redis

  def initialize(config: nil)
    @config = config || VIN::Config.new
  end

  def generate_id(data_type)
    generator.generate_ids(data_type, 1).first
  end

  def generate_ids(data_type, count)
    ids = []
    # The Lua script can't always return as many IDs as you may want. So we loop
    # until we have the exact amount.
    while ids.length < count
      initial_id_count = ids.length
      ids += generator.generate_ids(data_type, count - ids.length)
      # Ensure the ids array keeps growing as infinite loop insurance
      return ids unless ids.length > initial_id_count
    end
    ids
  end

  private

  def generator
    @generator ||= Generator.new(config: @config)
  end
end

require "vin/generator"
require "vin/id"
require "vin/lua_script"
require "vin/request"
require "vin/response"
require "vin/timestamp"
require "vin/config"
