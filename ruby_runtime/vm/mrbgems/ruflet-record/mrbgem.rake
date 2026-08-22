# frozen_string_literal: true

MRuby::Gem::Specification.new("ruflet-record") do |spec|
  spec.license = "MIT"
  spec.author = "Ruflet"
  spec.summary = "RufletRecord ORM and embedded SQLite"

  root = File.expand_path("../../../..", __dir__)
  lib = File.join(root, "packages/ruflet_record/lib")
  spec.rbfiles = %w[
    ruflet_record/version.rb
    ruflet_record/errors.rb
    ruflet_record/inflector.rb
    ruflet_record/sql.rb
    ruflet_record/column.rb
    ruflet_record/adapters/sqlite_adapter.rb
    ruflet_record/schema.rb
    ruflet_record/relation.rb
    ruflet_record/base.rb
    ruflet_record.rb
  ].map { |path| File.join(lib, path) }

  spec.cc.include_paths << File.join(root, "ruby_runtime/vm/vendor/sqlite")
  spec.cc.defines << "SQLITE_THREADSAFE=1"
  spec.cc.defines << "SQLITE_OMIT_LOAD_EXTENSION=1"
  spec.cc.defines << "SQLITE_DEFAULT_FOREIGN_KEYS=1"
  spec.cc.defines << "SQLITE_ENABLE_FTS5=1"
  spec.cc.defines << "SQLITE_ENABLE_JSON1=1"
end
