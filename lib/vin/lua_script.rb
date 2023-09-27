# frozen_string_literal: true

require "erb"
require "vin/config"

class VIN
  module LuaScript
    LUA_SCRIPT_PATH = "lua/id-generation.lua.erb"

    def self.generate_file(config: nil)
      config ||= VIN::Config.new
      binding = binding()
      binding.local_variable_set(:config, config)
      @generate_file ||= ERB.new(
        File.read(
          File.expand_path("../../#{LUA_SCRIPT_PATH}", File.dirname(__FILE__)),
        ),
      ).result(binding)
    end

    # Used in tests to ensure that the file is regenerated.
    def self.reset_cache
      @generate_file = nil
    end
  end
end
