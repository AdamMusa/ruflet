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

first.update!(done: true)
raise "update failed" unless Note.done.count == 2
raise "timestamp casting failed" unless first.reload.updated_at.is_a?(Time)

json_value = RufletRecord.connection.select_value("SELECT json_extract('{\"count\":7}', '$.count')")
raise "SQLite JSON support failed" unless json_value == 7
RufletRecord.connection.execute("CREATE VIRTUAL TABLE note_search USING fts5(title)")
RufletRecord.connection.execute("INSERT INTO note_search(title) VALUES (?)", ["searchable note"])
match_count = RufletRecord.connection.select_value("SELECT COUNT(*) FROM note_search WHERE note_search MATCH ?", ["searchable"])
raise "SQLite FTS5 support failed" unless match_count == 1

RufletRecord.connection.close
puts "ruflet_record mruby sqlite smoke: ok"
