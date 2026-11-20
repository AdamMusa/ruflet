# frozen_string_literal: true

require_relative "test_helper"

# Table names, foreign keys and association classes come from the
# Inflector. pluralize turned every final y into "ies" (survey -> surveies),
# and singularize did not undo pluralize's "es" after ss (addresses ->
# addresse), so a Survey model looked for a "surveies" table and
# has_many :addresses looked for an Addresse class. Words the old rules got
# right (soliloquies, crevasses, abuses) must keep their results.
class InflectorTest < Minitest::Test
  WORDS = {
    "user" => "users", "category" => "categories", "survey" => "surveys", "day" => "days",
    "key" => "keys", "toy" => "toys", "box" => "boxes", "match" => "matches", "wish" => "wishes",
    "quiz" => "quizes", "address" => "addresses", "class" => "classes", "status" => "statuses",
    "bus" => "buses", "alias" => "aliases", "house" => "houses", "note" => "notes",
    "soliloquy" => "soliloquies", "colloquy" => "colloquies", "order_status" => "order_statuses", "crevasse" => "crevasses",
    "impasse" => "impasses", "posse" => "posses", "abuse" => "abuses", "cause" => "causes"
  }.freeze

  def test_pluralize_and_singularize_are_inverses
    WORDS.each do |singular, plural|
      assert_equal plural, RufletRecord::Inflector.pluralize(singular), "pluralize(#{singular})"
      assert_equal singular, RufletRecord::Inflector.singularize(plural), "singularize(#{plural})"
    end
  end

  def test_classify_underscore_and_constantize
    assert_equal "Address", RufletRecord::Inflector.classify("addresses")
    assert_equal "BlogPost", RufletRecord::Inflector.classify("blog_posts")
    assert_equal "blog_post", RufletRecord::Inflector.underscore("BlogPost")
    assert_equal "html_page", RufletRecord::Inflector.underscore("HTMLPage")
    assert_equal "admin/user", RufletRecord::Inflector.underscore("Admin::User")
    assert_equal RufletRecord::Base, RufletRecord::Inflector.constantize("::RufletRecord::Base")
  end
end

class InflectedSchemaTest < RufletRecordTestCase
  def setup
    super
    RufletRecord::Schema.define do
      create_table :surveys do |table|
        table.string :title
      end
      create_table :addresses do |table|
        table.references :survey, foreign_key: true
        table.string :line
      end
    end
    Object.const_set(:Survey, Class.new(RufletRecord::Base) { has_many :addresses })
    Object.const_set(:Address, Class.new(RufletRecord::Base) { belongs_to :survey })
  end

  def teardown
    Object.send(:remove_const, :Survey) if Object.const_defined?(:Survey)
    Object.send(:remove_const, :Address) if Object.const_defined?(:Address)
    super
  end

  def test_models_and_associations_find_their_tables_and_classes
    assert_equal "surveys", Survey.table_name
    survey = Survey.create!(title: "Commute")
    address = Address.new(line: "1 Main St")
    address.survey = survey
    address.save!

    assert_equal [address.id], survey.addresses.ids
    assert_equal survey, address.survey
    foreign_keys = RufletRecord.connection.select_all("PRAGMA foreign_key_list(addresses)")
    assert_equal ["surveys"], foreign_keys.map { |row| row["table"] }
  end
end
