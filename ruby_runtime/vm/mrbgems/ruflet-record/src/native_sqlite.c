#include <mruby.h>
#include <mruby/array.h>
#include <mruby/class.h>
#include <mruby/data.h>
#include <mruby/error.h>
#include <mruby/hash.h>
#include <mruby/string.h>

#include "sqlite3.h"

typedef struct {
  sqlite3 *handle;
} ruflet_sqlite_database;

static struct RClass *native_error_class;

static void database_free(mrb_state *mrb, void *pointer) {
  ruflet_sqlite_database *database = (ruflet_sqlite_database *)pointer;
  if (database == NULL) return;
  if (database->handle != NULL) sqlite3_close_v2(database->handle);
  mrb_free(mrb, database);
}

static const struct mrb_data_type database_type = {
  "RufletRecord::NativeSQLite::Database", database_free
};

static ruflet_sqlite_database *get_database(mrb_state *mrb, mrb_value self) {
  ruflet_sqlite_database *database = DATA_GET_PTR(mrb, self, &database_type,
                                                   ruflet_sqlite_database);
  if (database == NULL || database->handle == NULL) {
    mrb_raise(mrb, native_error_class, "database is closed");
  }
  return database;
}

static void raise_database_error(mrb_state *mrb, sqlite3 *database,
                                 const char *prefix) {
  const char *detail = database == NULL ? "SQLite error" : sqlite3_errmsg(database);
  mrb_value message = mrb_str_new_cstr(mrb, prefix);
  mrb_str_cat_lit(mrb, message, ": ");
  mrb_str_cat_cstr(mrb, message, detail);
  mrb_exc_raise(mrb, mrb_exc_new_str(mrb, native_error_class, message));
}

static mrb_value database_initialize(mrb_state *mrb, mrb_value self) {
  char *path;
  mrb_get_args(mrb, "z", &path);

  ruflet_sqlite_database *database =
      (ruflet_sqlite_database *)mrb_calloc(mrb, 1, sizeof(*database));
  int result = sqlite3_open_v2(path, &database->handle,
                               SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE |
                                   SQLITE_OPEN_FULLMUTEX,
                               NULL);
  if (result != SQLITE_OK) {
    sqlite3 *failed_handle = database->handle;
    database->handle = NULL;
    const char *message = failed_handle == NULL ? "unable to open database"
                                                 : sqlite3_errmsg(failed_handle);
    mrb_value rendered = mrb_str_new_cstr(mrb, message);
    if (failed_handle != NULL) sqlite3_close_v2(failed_handle);
    mrb_free(mrb, database);
    mrb_exc_raise(mrb, mrb_exc_new_str(mrb, native_error_class, rendered));
  }

  sqlite3_extended_result_codes(database->handle, 1);
  DATA_TYPE(self) = &database_type;
  DATA_PTR(self) = database;
  return self;
}

static int bind_value(mrb_state *mrb, sqlite3_stmt *statement, int index,
                      mrb_value value) {
  if (mrb_nil_p(value)) {
    return sqlite3_bind_null(statement, index);
  }
  if (mrb_true_p(value)) {
    return sqlite3_bind_int(statement, index, 1);
  }
  if (mrb_false_p(value)) {
    return sqlite3_bind_int(statement, index, 0);
  }
  if (mrb_integer_p(value)) {
    return sqlite3_bind_int64(statement, index, (sqlite3_int64)mrb_integer(value));
  }
  if (mrb_float_p(value)) {
    return sqlite3_bind_double(statement, index, (double)mrb_float(value));
  }
  if (mrb_string_p(value)) {
    return sqlite3_bind_text(statement, index, RSTRING_PTR(value),
                             (int)RSTRING_LEN(value), SQLITE_TRANSIENT);
  }
  value = mrb_obj_as_string(mrb, value);
  return sqlite3_bind_text(statement, index, RSTRING_PTR(value),
                           (int)RSTRING_LEN(value), SQLITE_TRANSIENT);
}

static mrb_value column_value(mrb_state *mrb, sqlite3_stmt *statement,
                              int column) {
  switch (sqlite3_column_type(statement, column)) {
  case SQLITE_INTEGER:
    return mrb_int_value(mrb, (mrb_int)sqlite3_column_int64(statement, column));
  case SQLITE_FLOAT:
    return mrb_float_value(mrb, (mrb_float)sqlite3_column_double(statement, column));
  case SQLITE_TEXT: {
    const unsigned char *text = sqlite3_column_text(statement, column);
    int length = sqlite3_column_bytes(statement, column);
    return mrb_str_new(mrb, (const char *)text, length);
  }
  case SQLITE_BLOB: {
    const void *blob = sqlite3_column_blob(statement, column);
    int length = sqlite3_column_bytes(statement, column);
    return mrb_str_new(mrb, (const char *)blob, length);
  }
  default:
    return mrb_nil_value();
  }
}

static mrb_value database_execute(mrb_state *mrb, mrb_value self) {
  mrb_value sql_value;
  mrb_value binds = mrb_ary_new(mrb);
  mrb_get_args(mrb, "S|A", &sql_value, &binds);
  ruflet_sqlite_database *database = get_database(mrb, self);

  sqlite3_stmt *statement = NULL;
  int result = sqlite3_prepare_v2(database->handle, RSTRING_PTR(sql_value),
                                  (int)RSTRING_LEN(sql_value), &statement, NULL);
  if (result != SQLITE_OK) raise_database_error(mrb, database->handle, "prepare failed");

  mrb_int bind_count = RARRAY_LEN(binds);
  if (sqlite3_bind_parameter_count(statement) != bind_count) {
    sqlite3_finalize(statement);
    mrb_raise(mrb, native_error_class, "wrong number of bind values");
  }
  for (mrb_int index = 0; index < bind_count; index++) {
    result = bind_value(mrb, statement, (int)index + 1, mrb_ary_ref(mrb, binds, index));
    if (result != SQLITE_OK) {
      sqlite3_finalize(statement);
      raise_database_error(mrb, database->handle, "bind failed");
    }
  }

  mrb_value rows = mrb_ary_new(mrb);
  while ((result = sqlite3_step(statement)) == SQLITE_ROW) {
    mrb_value row = mrb_hash_new(mrb);
    int count = sqlite3_column_count(statement);
    for (int column = 0; column < count; column++) {
      const char *name = sqlite3_column_name(statement, column);
      mrb_hash_set(mrb, row, mrb_str_new_cstr(mrb, name),
                   column_value(mrb, statement, column));
    }
    mrb_ary_push(mrb, rows, row);
  }

  if (result != SQLITE_DONE) {
    sqlite3_finalize(statement);
    raise_database_error(mrb, database->handle, "execute failed");
  }
  sqlite3_finalize(statement);
  return rows;
}

static mrb_value database_execute_batch(mrb_state *mrb, mrb_value self) {
  char *sql;
  mrb_get_args(mrb, "z", &sql);
  ruflet_sqlite_database *database = get_database(mrb, self);
  char *message = NULL;
  int result = sqlite3_exec(database->handle, sql, NULL, NULL, &message);
  if (result != SQLITE_OK) {
    mrb_value rendered = mrb_str_new_cstr(mrb, message == NULL ? sqlite3_errmsg(database->handle) : message);
    sqlite3_free(message);
    mrb_exc_raise(mrb, mrb_exc_new_str(mrb, native_error_class, rendered));
  }
  return mrb_ary_new(mrb);
}

static mrb_value database_changes(mrb_state *mrb, mrb_value self) {
  return mrb_int_value(mrb, sqlite3_changes(get_database(mrb, self)->handle));
}

static mrb_value database_last_insert_row_id(mrb_state *mrb, mrb_value self) {
  return mrb_int_value(mrb, (mrb_int)sqlite3_last_insert_rowid(
                                get_database(mrb, self)->handle));
}

static mrb_value database_close(mrb_state *mrb, mrb_value self) {
  ruflet_sqlite_database *database = DATA_GET_PTR(
      mrb, self, &database_type, ruflet_sqlite_database);
  if (database != NULL && database->handle != NULL) {
    int result = sqlite3_close_v2(database->handle);
    if (result != SQLITE_OK) raise_database_error(mrb, database->handle, "close failed");
    database->handle = NULL;
  }
  return mrb_nil_value();
}

void mrb_ruflet_record_gem_init(mrb_state *mrb) {
  struct RClass *ruflet_record = mrb_define_module(mrb, "RufletRecord");
  struct RClass *native = mrb_define_module_under(mrb, ruflet_record, "NativeSQLite");
  native_error_class = mrb_define_class_under(mrb, native, "Error", E_RUNTIME_ERROR);
  struct RClass *database = mrb_define_class_under(mrb, native, "Database", mrb->object_class);
  MRB_SET_INSTANCE_TT(database, MRB_TT_CDATA);
  mrb_define_method(mrb, database, "initialize", database_initialize, MRB_ARGS_REQ(1));
  mrb_define_method(mrb, database, "execute", database_execute, MRB_ARGS_ARG(1, 1));
  mrb_define_method(mrb, database, "execute_batch", database_execute_batch, MRB_ARGS_REQ(1));
  mrb_define_method(mrb, database, "changes", database_changes, MRB_ARGS_NONE());
  mrb_define_method(mrb, database, "last_insert_row_id", database_last_insert_row_id, MRB_ARGS_NONE());
  mrb_define_method(mrb, database, "close", database_close, MRB_ARGS_NONE());
}

void mrb_ruflet_record_gem_final(mrb_state *mrb) { (void)mrb; }
