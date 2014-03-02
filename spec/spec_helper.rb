require 'machinist/active_record'
require 'sham'
require 'faker'
require 'squeel/context'
require 'squeel/adapters/active_record/context'

module ActiveRecord
  # Shamelessly swiped from the AR test code
  class SQLCounter
    IGNORED_SQL = [/^PRAGMA /, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /^SHOW max_identifier_length/,
      /SELECT name\s+FROM sqlite_master\s+WHERE type = 'table' AND NOT name = 'sqlite_sequence'/]
    IGNORED_SQL.concat [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from all_triggers/im]

    def initialize
      $queries_executed = []
    end

    def call(name, start, finish, message_id, values)
      sql = values[:sql]

      unless 'CACHE' == values[:name]
        $queries_executed << sql unless IGNORED_SQL.any? { |r| sql =~ r }
      end
    end
  end
  ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
end

unless ENV['DEPRECATIONS']
  ActiveSupport::Deprecation.silenced = true
end

Dir[File.expand_path('../helpers/*.rb', __FILE__)].each do |f|
  require f
end
require File.expand_path('../support/schema.rb', __FILE__)
require File.expand_path('../support/models.rb', __FILE__)

Sham.define do
  name     { Faker::Name.name }
  title    { Faker::Lorem.sentence }
  body     { Faker::Lorem.paragraph }
  salary   {|index| 30000 + (index * 1000)}
  tag_name { Faker::Lorem.words(3).join(' ') }
  note     { Faker::Lorem.words(7).join(' ') }
  object_name { Faker::Lorem.words(1).first }
end

RSpec.configure do |config|
  config.before(:suite) do
    puts '=' * 80
    puts "Running specs against Active Record #{ActiveRecord::VERSION::STRING} and Arel #{Arel::VERSION}..."
    puts '=' * 80
    Models.make
  end
  config.before(:all)   { Sham.reset(:before_all) }
  config.before(:each)  { Sham.reset(:before_each) }

  config.include SqueelHelper
end

RSpec::Matchers.define :be_like do |expected|
  match do |actual|
    actual.gsub(/^\s+|\s+$/, '').gsub(/\s+/, ' ').strip ==
      expected.gsub(/^\s+|\s+$/, '').gsub(/\s+/, ' ').strip
  end
end

require 'squeel'

Squeel.configure do |config|
  config.load_core_extensions :hash, :symbol
end
