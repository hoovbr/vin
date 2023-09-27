# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "tty-prompt"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc "Sets lib version to the semantic version given, and push it to remote."
task :bump, [:v] do |_t, args|
  version = args[:v] || raise("A version is required. Pass it like `rake bump[1.2.3]`")
  next unless TTY::Prompt.new.yes?("Would you like to set the new version of the app to be '#{version}'?")

  version_filename = "lib/vin/version.rb"
  version_file_contents = File.read(version_filename)
  new_version_file_contents = version_file_contents.gsub(/VERSION = "(?:.*)"/, "VERSION = \"#{version}\"")
  File.open(version_filename, "w") { |file| file.puts new_version_file_contents }
  sh("bundle install")
  sh("git add #{version_filename} Gemfile.lock")
  sh("git commit -m 'Bump app version to v#{version}.'")
  sh("git push origin")
end
