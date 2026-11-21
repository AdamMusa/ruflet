# frozen_string_literal: true

# Run with ruby_runtime/third_party/mruby/build/host_vm/bin/mruby after building
# the host_vm target. RufletRecord is preloaded into that VM.
require "ruflet_record"

RufletRecord.establish_connection(database: ":memory:")

RufletRecord::Schema.define do
  create_table :notes do |table|
    table.string :title, null: false
    table.boolean :done, default: false
    table.timestamps
  end
end

class Note < RufletRecord::Base
  validates_presence_of :title
  scope :done, -> { where(done: true) }
end

pending = Note.where(done: false).order(:id)
raise "relations must be lazy" if pending.loaded?

first = Note.create!(title: "Ship RufletRecord")
second = Note.create!(title: "Verify mruby", done: true)
raise "insert failed" unless first.id == 1 && second.id == 2
raise "lazy query failed" unless pending.pluck(:title) == ["Ship RufletRecord"]
raise "scope failed" unless Note.done.first.title == "Verify mruby"
raise "count failed" unless Note.count == 2
raise "endless range failed" unless Note.where(id: 2..).pluck(:title) == ["Verify mruby"]
raise "beginless range failed" unless Note.where(id: ...2).pluck(:title) == ["Ship RufletRecord"]

first.update!(done: true)
raise "update failed" unless Note.done.count == 2
raise "timestamp casting failed" unless first.reload.updated_at.is_a?(Time)

json_value = RufletRecord.connection.select_value("SELECT json_extract('{\"count\":7}', '$.count')")
raise "SQLite JSON support failed" unless json_value == 7
RufletRecord.connection.execute("CREATE VIRTUAL TABLE note_search USING fts5(title)")
RufletRecord.connection.execute("INSERT INTO note_search(title) VALUES (?)", ["searchable note"])
match_count = RufletRecord.connection.select_value("SELECT COUNT(*) FROM note_search WHERE note_search MATCH ?", ["searchable"])
raise "SQLite FTS5 support failed" unless match_count == 1

# A return, break or throw out of a transaction block commits it and ends it.
def ruflet_record_smoke_return
  Note.transaction do
    Note.create!(title: "Returned")
    return :returned
  end
end
raise "transaction return value failed" unless ruflet_record_smoke_return == :returned
[1].each { Note.transaction { Note.create!(title: "Broke out"); break } }
catch(:done) { Note.transaction { Note.create!(title: "Thrown out"); throw :done } }
transaction_depth = RufletRecord.connection.instance_variable_get(:@transaction_depth)
raise "non-local exit left a transaction open" unless transaction_depth.zero?
RufletRecord.connection.execute("BEGIN IMMEDIATE")
RufletRecord.connection.execute("ROLLBACK")
raise "non-local exit lost writes" unless Note.count == 5

# The VM's threads are cooperative, so its connection takes no lock, and
# nested transactions are still savepoints.
raise "mruby connection must not lock" unless RufletRecord.connection.instance_variable_get(:@lock).is_a?(RufletRecord::Adapters::NullLock)
begin
  Note.transaction do
    Note.create!(title: "Outer")
    begin
      Note.transaction { Note.create!(title: "Inner"); raise "inner fails" }
    rescue RuntimeError => error
      raise error unless error.message == "inner fails"
    end
    raise "savepoint rollback failed" unless Note.where(title: "Inner").count.zero? && Note.where(title: "Outer").count == 1
    raise "outer fails"
  end
rescue RuntimeError => error
  raise error unless error.message == "outer fails"
end
raise "nested transaction rollback failed" unless Note.count == 5

# touch saves updated_at only; other unsaved changes stay pending.
first.title = "Renamed"
first.touch
raise "touch dropped a pending change" unless first.changes.keys == ["title"]
raise "touch saved a pending change" unless Note.find(first.id).title == "Ship RufletRecord"
first.title = "Ship RufletRecord"
raise "touch left updated_at pending" if first.changed?

# An error raised in a transaction block keeps its class and rolls back.
begin
  Note.transaction do
    Note.create!(title: "Rolled back")
    Note.create!(title: nil)
  end
  raise "invalid record was saved"
rescue RufletRecord::RecordInvalid => error
  raise "transaction error lost its message" unless error.message.include?("Title")
end
raise "transaction rollback failed" unless Note.count == 5

RufletRecord.connection.close
puts "ruflet_record mruby sqlite smoke: ok"
