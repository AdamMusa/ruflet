# RufletRecord

RufletRecord is a small, lazy SQLite ORM for Ruflet applications. Its API is
shaped like the useful core of Active Record, but it has no Rails or
ActiveSupport dependency and is compiled directly into Ruflet's mruby VM.

The gem runs on CRuby with the `sqlite3` gem and on Ruflet's mruby runtime with
the bundled native SQLite 3.53.4 bridge.

## Setup

```ruby
require "ruflet_record"

RufletRecord.establish_connection(
  database: File.join(Dir.pwd, "storage", "app.sqlite3"),
  journal_mode: :wal,
  timeout: 5_000
)
```

`foreign_keys` defaults to `true`. Use `database: ":memory:"` in tests.

## Schema

```ruby
RufletRecord::Schema.define do
  create_table :users, if_not_exists: true do |table|
    table.string :name, null: false
    table.string :email
    table.boolean :active, default: true
    table.timestamps
    table.index :email, unique: true
  end

  create_table :posts, if_not_exists: true do |table|
    table.references :user, null: false, foreign_key: { on_delete: :cascade }
    table.string :title, null: false
    table.text :body
    table.timestamps
  end
end
```

Supported column helpers are `string`, `text`, `integer`, `float`, `decimal`,
`boolean`, `datetime`, `date`, `binary`, `json`, `references`, and
`timestamps`. Schema operations include `create_table`, `drop_table`,
`add_column`, `add_index`, `remove_index`, and `rename_table`.

`references` creates an index by default. Pass `index: false` to omit it and
`foreign_key: true` to reference the conventionally named table. A hash can
configure `to_table`, `primary_key`, `on_delete`, and `on_update`; supported
actions are `cascade`, `restrict`, `set_null`, `set_default`, and `no_action`.

For application migration classes:

```ruby
class CreateTasks < RufletRecord::Migration
  def change
    create_table :tasks do |table|
      table.string :title, null: false
      table.boolean :done, default: false
      table.timestamps
    end
  end
end

CreateTasks.migrate(:up)
```

## Models

```ruby
class User < RufletRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :email

  has_many :posts
  has_one :profile

  scope :active, -> { where(active: true) }
end

class Post < RufletRecord::Base
  belongs_to :user
end
```

Table names are inferred (`Post` → `posts`). Override conventions where
needed:

```ruby
class LegacyEntry < RufletRecord::Base
  self.table_name = "entries"
  self.primary_key = "entry_id"
end
```

## Persistence

```ruby
user = User.create!(name: "Ada", email: "ada@example.com")
post = user.posts.create!(title: "Notes")

user.update!(active: false)
user.reload
user.destroy
```

The common persistence API includes `new`, `create`, `create!`, `save`,
`save!`, `update`, `update!`, `update_columns`, `touch`, `destroy`, `delete`,
`reload`, `find_or_initialize_by`, `find_or_create_by`, and
`find_or_create_by!`.

## Lazy queries

Building a relation never touches SQLite:

```ruby
query = User.where(active: true).order(name: :asc).limit(20)
# No SQL has run yet.

users = query.to_a # SQL runs here.
```

These methods only build immutable relation objects:

- `where` and `where.not`
- `order` and `reorder`
- `select` and `distinct`
- `limit` and `offset`
- `joins`
- model scopes and association readers

SQL executes when records or scalar values are requested with `each`, `to_a`,
`first`, `last`, `find`, `find_by`, `pluck`, `pick`, `ids`, `count`, `sum`,
`average`, `minimum`, `maximum`, or `exists?`. Writes execute immediately.

```ruby
User.where("age >= ?", 18)
User.where(id: [1, 2, 3])
User.where(created_at: start_time..end_time)
User.where.not(active: false)
User.order(age: :desc).pluck(:name, :age)
```

Values use SQLite bind parameters. Identifiers are quoted. Raw ordering is
strictly validated; use `RufletRecord.sql(...)` only for trusted application
SQL:

```ruby
User.select(RufletRecord.sql("COUNT(*) AS total"))
```

## Transactions

```ruby
User.transaction do
  user = User.create!(name: "Grace")
  user.posts.create!(title: "Compiler notes")
end
```

Nested transactions use SQLite savepoints.

## Deliberate limits

RufletRecord is not Rails Active Record. It deliberately omits callbacks,
STI, eager loading, polymorphic associations, database portability, and Arel.
Hard invariants should use SQLite constraints and unique indexes; the included
presence and uniqueness validations exist for user-facing errors.

For uncommon SQL, use `RufletRecord.connection.execute(sql, binds)` directly.
