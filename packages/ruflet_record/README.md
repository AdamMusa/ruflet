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

A `json` column is a TEXT column. A Hash or Array assigned to it is stored as
JSON text, and every value reads back as the stored text, so use
`JSON.parse(record.value)` to get the data back. `where(value: hash)` matches
that text. A Hash or Array bound in raw SQL (`connection.execute` or
`where("...", value)`) is passed to the SQLite driver as given, so bind
`JSON.generate(value)` there to match a stored value.
`datetime` values are stored as UTC: a `Time` keeps its instant, and a
string's `Z` or `+HH:MM` offset is applied. They read back as UTC times, so
call `localtime` to show local time.

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
`find_or_create_by!`. `update_columns` and `touch` write only their own
columns, without validations. Other unsaved changes stay pending for the next
`save`.

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
User.where(age: 18..)
User.where(created_at: ...cutoff)
User.where.not(active: false)
User.order(age: :desc).pluck(:name, :age)
```

A range with an open end leaves that side unbounded, as in Active Record:
`18..` is `age >= 18`, `..17` is `age <= 17`, `...18` is `age < 18`, and
`nil..nil` matches every row.

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

Every thread shares the one connection. On CRuby a thread holds it for each
statement and for a whole transaction block. Another thread's reads and writes
wait until the block ends; they never join its transaction. A thread that
waits longer than `timeout` milliseconds (5000 by default) gets
`StatementInvalid: database is locked`. So do not wait inside a transaction
block for another thread that uses the database. On Ruflet's mruby VM threads
are cooperative and the connection takes no lock.

## Deliberate limits

RufletRecord is not Rails Active Record. It deliberately omits callbacks,
STI, eager loading, polymorphic associations, database portability, and Arel.
Hard invariants should use SQLite constraints and unique indexes; the included
presence and uniqueness validations exist for user-facing errors.

For uncommon SQL, use `RufletRecord.connection.execute(sql, binds)` directly.
