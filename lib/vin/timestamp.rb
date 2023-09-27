# frozen_string_literal: true

class VIN
  class Timestamp
    ONE_SECOND_IN_MILLIS = 1_000
    ONE_MILLI_IN_MICRO_SECS = 1_000

    attr_reader :milliseconds, :epoch

    def initialize(milliseconds, epoch: 0)
      @milliseconds = milliseconds
      @epoch = epoch
    end

    def seconds
      (milliseconds / ONE_SECOND_IN_MILLIS).floor
    end

    def microseconds_part
      (milliseconds - (seconds * ONE_SECOND_IN_MILLIS)) * ONE_MILLI_IN_MICRO_SECS
    end

    alias to_i milliseconds

    def to_time
      Time.at(with_unix_epoch.seconds, with_unix_epoch.microseconds_part)
    end

    def with_unix_epoch
      @with_unix_epoch ||= with_epoch(0)
    end

    def with_epoch(new_epoch)
      new_milliseconds = milliseconds - (new_epoch - epoch)

      self.class.new(new_milliseconds, epoch: new_epoch)
    end

    def self.from_redis(seconds_part, microseconds_part)
      # NOTE: we're dropping the microseconds here because we don't need that
      # level of precision
      milliseconds = (
        (seconds_part * ONE_SECOND_IN_MILLIS) +
        (microseconds_part / ONE_MILLI_IN_MICRO_SECS)
      )

      new(milliseconds)
    end
  end
end
