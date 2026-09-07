# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ruflet_record"

class RufletRecordTestCase < Minitest::Test
  def setup
    @database_path = File.join(Dir.tmpdir, "ruflet_record_#{Process.pid}_#{object_id}.sqlite3")
    RufletRecord.establish_connection(database: @database_path)
    define_schema
    define_models
  end

  def teardown
    RufletRecord.connection.close
    File.delete(@database_path) if File.exist?(@database_path)
    Object.send(:remove_const, :User) if Object.const_defined?(:User)
    Object.send(:remove_const, :Post) if Object.const_defined?(:Post)
    Object.send(:remove_const, :Profile) if Object.const_defined?(:Profile)
  end

  private

  def define_schema
    RufletRecord::Schema.define do
      create_table :users do |table|
        table.string :name, null: false
        table.string :email
        table.integer :age, default: 0
        table.boolean :active, default: true
        table.timestamps
        table.index :email, unique: true
      end

      create_table :posts do |table|
        table.references :user, null: false
        table.string :title, null: false
        table.text :body
        table.timestamps
      end

      create_table :profiles do |table|
        table.references :user, null: false, index: false
        table.string :bio
      end
    end
  end

  def define_models
    Object.const_set(:User, Class.new(RufletRecord::Base) do
      validates_presence_of :name
      validates_uniqueness_of :email
      has_many :posts
      has_one :profile
      scope :active, -> { where(active: true) }
    end)

    Object.const_set(:Post, Class.new(RufletRecord::Base) do
      validates_presence_of :title
      belongs_to :user
    end)

    Object.const_set(:Profile, Class.new(RufletRecord::Base) do
      belongs_to :user
    end)
  end
end
