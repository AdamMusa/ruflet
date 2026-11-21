# frozen_string_literal: true

require_relative "test_helper"

# The public RufletRecord methods no other test called. ApiCoverageTest
# fails for any public method that no test calls.
class ApiSurfaceTest < RufletRecordTestCase
  def setup
    super
    @ada = User.create!(name: "Ada", email: "ada@example.com", age: 36)
    @grace = User.create!(name: "Grace", email: "grace@example.com", age: 45, active: false)
    Post.create!(user_id: @ada.id, title: "Engines")
    Post.create!(user_id: @ada.id, title: "Notes")
    Post.create!(user_id: @grace.id, title: "Compilers")
  end

  # --- Model class: queries ---------------------------------------------------

  def test_model_query_methods_return_relations_over_the_table
    assert_kind_of RufletRecord::Relation, User.all
    assert_equal %w[Ada Grace], User.all.order(:name).pluck(:name)
    assert_equal %w[Grace Ada], User.order(:name).reorder(name: :desc).pluck(:name)
    assert_equal [{ "name" => "Ada" }], User.select(:name).where(id: @ada.id).map { |user| user.attributes.compact.slice("name") }
    assert_equal [@ada.id], Post.select(:user_id).distinct.where(user_id: @ada.id).pluck(:user_id)
    assert_equal 40.5, User.average(:age)
    assert_equal @grace, User.find_by(name: "Grace")
    assert_nil User.find_by(name: "Nobody")
    assert_equal @ada, User.find_by!(email: "ada@example.com")
    assert_raises(RufletRecord::RecordNotFound) { User.find_by!(name: "Nobody") }
  end

  def test_joins_takes_an_explicit_join_and_rejects_anything_else
    titles = Post.joins('INNER JOIN "users" ON "users"."id" = "posts"."user_id"')
                 .where(RufletRecord::SQL::Literal.new('"users"."name"') => "Ada").order(:title).pluck(:title)

    assert_equal %w[Engines Notes], titles
    assert_raises(ArgumentError) { Post.joins("DROP TABLE posts") }
  end

  def test_find_or_methods_find_first_and_create_only_when_missing
    assert_equal @ada, User.find_or_create_by(email: "ada@example.com")
    assert_equal @ada, User.find_or_create_by!(email: "ada@example.com")

    built = User.find_or_initialize_by(name: "Linus")
    assert built.new_record?
    assert_equal "Linus", built.name

    created = User.find_or_create_by(name: "Linus")
    assert created.persisted?
    refute User.find_or_create_by(name: nil).persisted?, "an invalid record is returned unsaved"
    assert_raises(RufletRecord::RecordInvalid) { User.find_or_create_by!(name: nil) }
  end

  def test_destroy_all_destroys_each_record
    destroyed = Post.where(user_id: @ada.id).destroy_all

    assert_equal 2, destroyed.size
    assert destroyed.all?(&:destroyed?)
    assert_equal ["Compilers"], Post.pluck(:title)
    Post.destroy_all
    assert_equal 0, Post.count
  end

  # --- Model class: metadata --------------------------------------------------

  def test_column_metadata_and_reset_after_a_schema_change
    assert_equal %w[id name email age active created_at updated_at], User.column_names
    assert_includes RufletRecord::Base.descendants, User

    RufletRecord::Schema.new.add_column(:users, :nickname, :string, default: "none")
    assert_includes User.column_names, "nickname", "the schema change resets the column cache"
    assert_equal "none", User.new.read_attribute(:nickname)

    User.reset_column_information
    assert_includes User.columns_hash.keys, "nickname"
  end

  def test_instantiate_builds_a_persisted_record_from_a_row
    record = User.instantiate("id" => 99, "name" => "Row", "active" => 1, "age" => "7")

    assert record.persisted?
    assert_equal 99, record.id
    assert_equal true, record.active
    assert_equal 7, record.age
  end

  def test_validators_and_inherited_validators
    assert_equal [[:presence, "name", {}], [:uniqueness, "email", {}]], User.validators

    admin = Class.new(User)
    assert_equal User.validators, admin.validators
    refute admin.abstract_class
  end

  # --- Records ----------------------------------------------------------------

  def test_attribute_readers_writers_and_assignment
    user = User.new
    assert user.new_record?

    user.assign_attributes(name: "Ken", age: "3")
    assert_equal "Ken", user.name
    assert_equal 3, user.read_attribute(:age)
    user.age = 4
    assert_equal 4, user[:age]
    user[:email] = "ken@example.com"
    assert_equal "ken@example.com", user.attributes["email"]

    copy = user.attributes
    copy["name"] = "changed"
    assert_equal "Ken", user.name, "attributes returns a copy"
    assert user.respond_to?(:email=)
    assert_raises(NoMethodError) { user.not_a_column }
  end

  def test_valid_reports_errors_without_saving
    user = User.new(email: "ada@example.com")

    refute user.valid?
    assert_includes user.errors.full_messages.join(" "), "Name"
    assert user.new_record?
  end

  def test_update_columns_skips_validation_and_timestamps
    stamp = @ada.reload.updated_at

    assert @ada.update_columns(name: "")
    assert_equal "", @ada.reload.name
    assert_equal stamp, @ada.updated_at
    assert_raises(RufletRecord::RecordNotSaved) { User.new.update_columns(name: "x") }
  end

  def test_touch_sets_updated_at
    @ada.update_columns(updated_at: Time.utc(2000, 1, 1))

    assert @ada.touch
    assert_operator @ada.reload.updated_at, :>, Time.utc(2001, 1, 1)
    assert_raises(RufletRecord::RecordNotSaved) { User.new.touch }
  end

  # update_columns saves only the columns it is given; other unsaved changes
  # stay pending for the next save, as in Active Record (issue #124).
  def test_update_columns_keeps_other_unsaved_changes
    @ada.name = "Ada Lovelace"
    @ada.update_columns(age: 37)

    assert @ada.changed?
    assert_equal({ "name" => ["Ada", "Ada Lovelace"] }, @ada.changes)
    assert_equal ["Ada", 37], User.where(id: @ada.id).pluck(:name, :age).first
    @ada.save!
    assert_equal ["Ada Lovelace", 37], User.where(id: @ada.id).pluck(:name, :age).first
    refute @ada.changed?
  end

  def test_touch_keeps_other_unsaved_changes
    @ada.name = "Ada Lovelace"
    @ada.touch

    assert_equal ["name"], @ada.changes.keys
    assert_equal "Ada", User.find(@ada.id).name
    @ada.save!
    assert_equal "Ada Lovelace", User.find(@ada.id).name
  end

  # --- Relations ----------------------------------------------------------------

  def test_relation_query_and_aggregate_methods
    adults = User.where("age > ?", 30)

    assert_equal 40.5, adults.average(:age)
    assert_equal @grace, adults.find_by(active: false)
    assert_equal @ada, adults.find_by!(name: "Ada")
    assert_raises(RufletRecord::RecordNotFound) { adults.find_by!(name: "Nobody") }
    assert_equal %w[Grace Ada], adults.order(:name).reorder(age: :desc).pluck(:name)
    assert_equal [@ada.id], Post.where(user_id: @ada.id).select(:user_id).distinct.pluck(:user_id)
    assert_equal 1, Post.where(user_id: @grace.id).destroy_all.size
  end

  def test_load_runs_the_query_once
    relation = User.order(:name)
    refute relation.loaded?

    assert_same relation, relation.load
    assert relation.loaded?
    assert_equal %w[Ada Grace], relation.map(&:name)
  end

  def test_merge_combines_two_relations_of_one_model
    merged = User.where(active: true).merge(User.order(:name).limit(1))

    assert_equal ["Ada"], merged.pluck(:name)
    assert_raises(ArgumentError) { User.all.merge(Post.all) }
  end

  def test_joins_on_a_relation
    count = User.where(id: @ada.id).joins('INNER JOIN "posts" ON "posts"."user_id" = "users"."id"').count

    assert_equal 2, count
  end

  def test_add_where_appends_a_fragment
    fragment = RufletRecord::SQL::Fragment.new('"users"."age" > ?', [40])

    assert_equal ["Grace"], User.all.add_where(fragment).pluck(:name)
  end

  # --- Schema -------------------------------------------------------------------

  def test_schema_changes_tables_columns_and_indexes
    schema = RufletRecord::Schema.new
    schema.create_table(:tags) { |table| table.string :label }
    schema.add_index(:tags, :label, unique: true)

    connection = RufletRecord.connection
    connection.execute('INSERT INTO "tags" ("label") VALUES (?)', ["ruby"])
    assert_raises(RufletRecord::StatementInvalid) { connection.execute('INSERT INTO "tags" ("label") VALUES (?)', ["ruby"]) }

    schema.remove_index(:tags, :label)
    connection.execute('INSERT INTO "tags" ("label") VALUES (?)', ["ruby"])

    schema.rename_table(:tags, :labels)
    refute connection.table_exists?(:tags)
    assert connection.table_exists?(:labels)

    schema.drop_table(:labels)
    refute connection.table_exists?(:labels)
    schema.drop_table(:labels, if_exists: true)
  end

  def test_table_definition_column_types_indexes_and_foreign_keys
    definition = RufletRecord::TableDefinition.new(:readings, true)
    definition.float :ratio
    definition.decimal :price
    definition.date :day
    definition.datetime :at
    definition.binary :blob
    definition.index %i[day at], unique: true
    definition.add_foreign_key(:user_id, :user, on_delete: :cascade)

    assert_equal %w[id ratio price day at blob], definition.columns.map(&:first)
    assert_equal [[%w[day at], { unique: true }]], definition.indexes
    assert_equal [["user_id", "users", "id", :cascade, nil]], definition.foreign_keys

    RufletRecord::Schema.define do
      create_table :readings do |table|
        table.float :ratio
        table.decimal :price
        table.date :day
        table.datetime :at
        table.binary :blob
      end
    end
    columns = RufletRecord.connection.columns(:readings).to_h { |column| [column.name, column] }
    assert_equal %i[integer float decimal datetime datetime binary], columns.values.map(&:type)
    assert_equal "REAL", columns["ratio"].sql_type
  end

  # --- Migrations ---------------------------------------------------------------

  def test_migrate_runs_up_or_change_and_down
    up_and_down = Class.new(RufletRecord::Migration) do
      def up = create_table(:widgets) { |table| table.string :name }
      def down = drop_table(:widgets)
    end
    change_only = Class.new(RufletRecord::Migration) do
      def change = add_column(:users, :bio, :text)
    end

    up_and_down.migrate
    assert RufletRecord.connection.table_exists?(:widgets)
    up_and_down.migrate(:down)
    refute RufletRecord.connection.table_exists?(:widgets)

    change_only.migrate
    assert_includes User.column_names, "bio"
    assert_raises(RufletRecord::Error) { change_only.migrate(:down) }
    assert_raises(NoMethodError) { change_only.new.not_a_schema_method }
  end

  # --- Columns ------------------------------------------------------------------

  def test_columns_cast_and_describe_themselves
    columns = User.columns_hash

    assert columns["id"].primary?
    refute columns["name"].null?
    assert columns["email"].null?
    assert_equal "VARCHAR", columns["name"].sql_type
    assert_equal "0", columns["age"].default
    assert_equal 12, columns["age"].cast("12")
    assert_equal true, columns["active"].cast("1")
    assert_equal false, columns["active"].cast("false")
    assert_equal Time.utc(2026, 2, 3, 4, 5, 6), columns["created_at"].cast("2026-02-03 04:05:06")
    assert_equal "text", columns["name"].cast("text")
    assert_nil columns["age"].cast(nil)
    assert_equal 1.5, RufletRecord::Column.new("x", "REAL", true, nil, false).cast("1.5")
    assert_equal :decimal, RufletRecord::Column.new("x", "DECIMAL", true, nil, false).type
  end
end
