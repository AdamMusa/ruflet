/* SQLite is built into every Ruflet VM so Android, iOS and desktop expose the
 * same database behavior without relying on private platform libraries. */
#if defined(__clang__)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundef"
#pragma clang diagnostic ignored "-Wincompatible-pointer-types-discards-qualifiers"
#elif defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wundef"
#pragma GCC diagnostic ignored "-Wwrite-strings"
#endif
#include "../../../vendor/sqlite/sqlite3.c"
#if defined(__clang__)
#pragma clang diagnostic pop
#elif defined(__GNUC__)
#pragma GCC diagnostic pop
#endif
