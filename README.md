<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/logo-dark-mode.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/logo-light-mode.png">
    <img width=200>
  </picture>
  <h1>VIN</h1>
  <p><i>noun ‧ <strong>V</strong>ersatile <strong>I</strong>dentification <strong>N</strong>umber</i></p>
  <p><strong>A customizable Redis-powered Ruby client for generating unique, monotonically-increasing integer IDs, for use in distributed systems and databases.</strong></p>
  <a href="https://github.com/hoovbr/vin/releases">
    <img alt="Latest Release" src="https://img.shields.io/github/v/release/hoovbr/vin?sort=semver">
  </a>
  <a href="https://codeclimate.com/github/hoovbr/vin/maintainability">
    <img src="https://api.codeclimate.com/v1/badges/790449fb5d05f6a134a5/maintainability" />
  </a>
  <a href="https://codeclimate.com/github/hoovbr/vin/test_coverage">
    <img src="https://api.codeclimate.com/v1/badges/790449fb5d05f6a134a5/test_coverage" />
  </a>
  <a href="https://github.com/hoovbr/vin/actions/workflows/push.yml">
    <img alt="Tests & Linter" src="https://github.com/hoovbr/vin/actions/workflows/push.yml/badge.svg">
  </a>
  <a href="https://github.com/hoovbr/vin/issues">
    <img alt="Issues" src="https://img.shields.io/github/issues/hoovbr/vin?color=#86D492" />
  </a>
  <a href="https://twitter.com/intent/follow?screen_name=hoovbr">
    <img src="https://img.shields.io/twitter/follow/hoovbr?&logo=twitter" alt="Follow on Twitter">
  </a>
  <img src="https://views.whatilearened.today/views/github/hoovbr/vin.svg">

  <p align="center">
    <a href="#preview">View Demo</a>
    ·
    <a href="https://github.com/hoovbr/vin/issues/new/choose">Report Bug</a>
    ·
    <a href="https://github.com/hoovbr/vin/issues/new/choose">Request Feature</a>
  </p>
</div>

A customizable Redis-powered Ruby client for generating unique, monotonically-increasing integer IDs, for use in distributed systems and databases. Based heavily off of [Icicle](https://github.com/intenthq/icicle/), [Twitter Snowflake](https://en.wikipedia.org/wiki/Snowflake_ID), and [Dogtag](https://github.com/zillyinc/dogtag).

# Requirements

- Ruby 3+
- Redis 5+
- If you are going to store the ID in a database you'll need to make sure it can store 64-bit integers, (e.g. PostgreSQL, MySQL, etc.)

## Demo

<details><summary>Click here to view a simple demo</summary>
<p>

The gif below demonstrates how the ID generation works:

<div align="center">
  <img src="docs/demo.gif">
</div>

</p>
</details>

# Installation

Add this gem to your `Gemfile`:

```ruby
gem "hoov_vin"
```

And then run `bundle install` to install it.

# Usage

Follow the steps below to get started with VIN in your Ruby on Rails project. These steps assume your project is not yet live in production, so that you're free to make changes to your database schema and drop your existing database records.

1. Make sure the primary key type is set to `:bigint` when generating new models

To achieve this, create or update your `config/initializers/generators.rb` file:

```
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :bigint
end
```

This [happens to be the default](https://edgeguides.rubyonrails.org/active_record_basics.html#schema-conventions) for PostgreSQL and MySQL, but it's not the default for SQLite, so it's good to always be explicit.

2. Set up the VIN generator

Update your `config/application.rb` file to initialize the VIN generator singleton:

```ruby
…
require "vin"

class YourApp
  class Application < Rails::Application
    …
    # CAUTION: Avoid modifying the values below without fully understanding the implications in past IDs.
    config.id_generator = VIN.new(config: VIN::Config.new(
      custom_epoch: 1_672_531_200_000,
      timestamp_bits: 40,
      logical_shard_id_bits: 3,
      data_type_bits: 9,
      sequence_bits: 11,
      logical_shard_id_range: 0..0,
    ))
  end
end
```

To understand what each of these values mean, see the [Configuration](#configuration) section below.

3. Automatically generate and assign the VIN to models before saving them to the database

Create a new file in `app/models/concerns/has_vin.rb`:

```ruby
module HasVin
  extend ActiveSupport::Concern

  included do
    before_create :set_vin_if_needed
  end

  private

  def set_vin_if_needed
    id_generator = Rails.application.config.id_generator
    self.id ||= id_generator.generate_id(self.class::VIN_DATA_TYPE)
  end
end
```

This will guarantee that the VIN is generated and assigned to the model before it's saved to the database. The `VIN_DATA_TYPE` constant is used to differentiate between different types of models, so that they don't share the same ID space. For example, you might want to use a different `VIN_DATA_TYPE` for `User` models than you would for `Post` models.

Note that this assumes all your models are using a primary key named `id`. If you're not following the Rails convention of using `id` as the primary key, or if you're using composite primary keys, you'll need to modify this code to work with your specific setup. This could be one way to do it:

```ruby
…
def set_vin_if_needed
  # If using composite primary keys in Rails 7.1 and later
  return if defined?(self.class.primary_key) && self.class.primary_key.is_a?(Array)
  # If using composite primary keys in Rails 7.0 and earlier
  return if defined?(self.class.primary_keys)
  id_generator = Rails.application.config.id_generator
  self.id ||= id_generator.generate_id(self.class::VIN_DATA_TYPE)
end
…
```

4. Include the `HasVin` module in your base `ApplicationRecord` class

Create or update your base ActiveRecord abstract class, such as `app/models/application_record.rb`:

```
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true # If targetting Rails 6 or earlier
  primary_abstract_class # If targetting Rails 7 or later
  include HasVin
end
```

This will make sure the `HasVin` module is included in all your models.

>_**Note:** If you already have an existing codebase and database records, make sure you write the appropriate migration to change the primary key type to `:bigint` across the board, as well as migrate your existing records' IDs to VIN IDs._

## Usage outside of ActiveRecord

```ruby
vin = VIN.new
data_type = 0
vin.generate_id(data_type)
…
count = 100
vin.generate_ids(data_type, count)
…
id_number = vin.generate_id(data_type)
id = VIN::Id.new(id_number)
id.data_type #=> 42
id.sequence #=> 1
id.logical_shard_id #=> 0
id.custom_timestamp # time since custom epoch
id.timestamp.to_i #=> 28146773761 # Unix timestamp
id.timestamp.to_time # Ruby Time object
id.timestamp.epoch #=> 1646160000000
```

# Configuration

The VIN generator can be configured with the following parameters:

- `custom_epoch` or `VIN_CUSTOM_EPOCH` env var: The custom epoch is the timestamp that will be used as the starting point for generating VINs. It's expressed in milliseconds since the UNIX epoch (Jan 1st, 1970, 12:00 AM UTC). Example value: `1_672_531_200_000` (Jan 1st, 2023, 12:00 AM UTC). This value shouldn't be in the future, and should never be changed after its first config.
- `timestamp_bits` or `VIN_TIMESTAMP_BITS` env var: The number of bits to use for the timestamp. The more bits you use, the more time you'll have before the timestamp overflows. Example value: `40` (40 bits gives us 1099511627776 milliseconds, or 34.8 years, enough time any of us to retire 😇).
- `logical_shard_id_bits` or `VIN_LOGICAL_SHARD_ID_BITS` env var: The number of bits to use for the logical shard ID. The more bits you use, the more machines generating IDs you'll be able to have. Example value: `3` (3 bits gives us 8 logical shards, which means you can have 8 different servers generating ids).
- `data_type_bits` or `VIN_DATA_TYPE_BITS`: The number of bits to use for the data type. The more bits you use, the more different types of models (tables) you'll be able to have. Example value: `9` (9 bits gives us 512 different data types).
- `sequence_bits` or `VIN_SEQUENCE_BITS`: The number of bits to use for the sequence. The more bits you use, the more IDs you'll be able to generate per millisecond per logical shard. Example value: `11` (11 bits gives us 2048 ids per millisecond per logical shard).
- `logical_shard_id_range` or `VIN_LOGICAL_SHARD_ID_RANGE_MIN` + `VIN_LOGICAL_SHARD_ID_RANGE_MAX` env vars: The range of logical shard IDs to use. Example value: `0..7` (8 logical shards, numbered 0 through 7). Note that this must conform with the `logical_shard_id_bits` value. This parameter is optional, and defaults to `0..0` (a single logical shard with ID 0).
- `VIN_REDIS_URL` or `REDIS_URL` env var: The Redis URL to use for the Redis connection. Example value: `redis://localhost:6379/0`. This parameter is optional, and defaults to `redis://127.0.0.1:6379`.

**Note:** the sum of the `timestamp_bits`, `logical_shard_id_bits`, `data_type_bits`, and `sequence_bits` values must be 63. The remaining bit is used for the sign bit.

# FAQ

## Why not use incremental IDs?

Using incremental IDs in databases can have its drawbacks and limitations. One key reason to reconsider their use is the potential for data leakage and security vulnerabilities. Incremental IDs are predictable and sequential, making it easier for malicious actors to guess or access sensitive data by simply incrementing the ID. This can compromise data privacy and expose confidential information about the system, how many records exist, etc. Additionally, when databases are distributed or sharded, managing incremental IDs across multiple servers can lead to synchronization challenges and performance bottlenecks. Moreover, if records are ever deleted or the database is restructured, gaps in the sequence may arise, causing inconsistencies and complicating data analysis. Lastly, incremental IDs are not universally unique, which inevitably leads to collisions amongst different database tables, and can cause confusion or mistakes when debugging, analyzing, or manipulating data.

## Why not use UUIDs?

UUIDs (Universally Unique Identifiers) solve the problem of predictability and security, and also the generation of IDs in distributed systems, but they are long and complex, which can increase storage requirements and slow down indexing and query performance. Storing them as strings can also make them difficult to work with, and takes up more space than storing integer IDs. Although they can be encoded as integers too, they still take up 128 bits of storage when in integer format. Lastly, sorting them doesn't provide any usefulness, and their meaningless nature doesn't help with debugging or data analysis.

## Why not use ULIDs?

Using ULIDs (Universally Unique Lexicographically Sortable Identifiers) are the second best alternative, as they are sortable by time, don't impose immediate generation problems in distributed systems, and can also be encoded as integers. However, there are still a few drawbacks, such as they taking up 128 bits of storage, which may not be necessary if they are being used as database primary keys. Lastly, time is the only useful information encoded in them, so they don't provide any additional context or meaning to the data.

## Why use VINs?

At this point you can probably guess why we created VINs. They are the best at solving each weakness of the options listed above:

- VINs are not predictable, thus they don't impose the security and privacy vulnerabilities that comes with incremental IDs.
- VINs has zero collision probability, making them universally unique across the entire database.
    - This comes with the drawback of a self-imposed bottleneck on the generation. However, this is only an issue at absurd scales (thousands of record creations per milisecond, per server), and can be easily overcome by increasing the number of sequence bits or shards.
- VINs are 64-bit integers, making them more space-efficient than UUIDs and ULIDs, which take 128 bits at best.
- VINs can be sorted, earning a chronologically sorted list, thanks to the monotonically-increasing nature of the IDs.
- VINs encode additional context and meaning to the data it stores, such as the timestamp, data type, and shard ID, which can be used to identify the source of the data, optimizing distributed systems and debugging.
- VINs are fully customizable. As you could see in the [configuration](#configuration) section, you can customize the number of bits used for each component of the VIN, allowing you to optimize the VIN for your specific use case.

## How does it work?

### How are the IDs generated?

The IDs are composed by 64 bits, which are divided into 4 components: timestamp, shard ID (aka machine ID), data type, and sequence. It's important that it starts with the timestamp component, as that's what guarantees the IDs are sortable by time.

The number of bits that each of these components take up can be customized as seen in the [configuration](#configuration), but for the sake of this example, we'll use 40 bits for the timestamp, 3 bits for the shard ID, 9 bits for the data type, and 11 bits for the sequence. This adds up 63 bits, but since we're working with a signed integer, the first bit is reserved for the bit sign. This results in this binary representation:

```no-highlight
+----------------------+----------+--------------+----------------+
|      Timestamp       | Shard ID |  Data Type   |    Sequence    |
|      (40 bits)       | (3 bits) |   (9 bits)   |    (11 bits)   |
+----------------------+----------+--------------+----------------+
```

This is then converted to a decimal number, which is what we use as the ID. The timestamp is the number of milliseconds since the custom epoch defined by you during the configuration. The shard ID is a number that uniquely identifies the machine that generated the ID. The data type is a number that uniquely identifies the model that this ID will belong to. The sequence is a number that is incremented every time an ID is generated, and is reset to 0 every millisecond, a strategy used to avoid collisions.

### How are the IDs automatically assigned to records?

In Rails, when you create a new record, the `create` method is called on the model class, which creates the record in memory and then calls `save` on it. The `save` method will either call `create` or `update` depending on whether the record is new or not. If the record is not new, it will already have an ID assigned to it, in which case our method `set_vin_if_needed` in `HasVin` won't do anything. However, if the record is new, it will not have an ID assigned to it, in which case our method will generate and assign a VIN to it. This happens before the record gets sent to the database, so the database will not generate an ID for it.

## What about the performance?

Compared to the benefits of having VINs, the performance impact is negligible. The only performance impact is the time it takes to generate the VIN, which is around ~0.039ms (yes, that's not a typo, it's less than 1/25th of a millisecond).

## Any issues I should be aware of?

Be careful of using VIN IDs with JavaScript, since it [doesn't handle 64 bit integers well](http://stackoverflow.com/questions/9643626/javascript-cant-handle-64-bit-integers-can-it). You'll probably want to work with them as strings.

# Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rake spec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`.

To bump the lib's version, run `bundle exec rake bump[1.2.3]` (replacing the value with the desired version).

To release a new version, update the version number (via `bundle exec rake bump` as explained above), and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

# TODO

- Support multiple Redis servers
- Replace the lua script with Ruby code.

# Contributing

If you spot something wrong, missing, or if you'd like to propose improvements to this project, please open an Issue or a Pull Request with your ideas and we promise to get back to you within 24 hours! 😇

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](CODE_OF_CONDUCT.md).

For a list of issues worth tackling check out: https://github.com/hoovbr/vin/issues

# Popularity

<img width=500 src="https://api.star-history.com/svg?repos=hoovbr/vin&type=Date">
