# Shared by the rails-postgres scripts. Settings come from wt's config (see project.env).
DB_PREFIX=${WT_DB_PREFIX:?set WT_DB_PREFIX in your wt project settings}
DEV_DB=${DB_PREFIX}_development
TEST_DB=${DB_PREFIX}_test
# Never connected to, so new worktrees can clone it while the main checkout's server runs
SNAPSHOT_DB=${WT_SNAPSHOT_DB:-${DB_PREFIX}_wt_snapshot}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

die() { echo "wt: $*" >&2; exit 1; }

# Branch -> identifier-safe suffix, short enough for "<prefix>_test_<slug><TEST_ENV_NUMBER>"
db_slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | cut -c1-30; }

db_exists() { [ "$(psql -X -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '$1'")" = 1 ]; }

# With PostgreSQL 18+ on btrfs, XFS, or APFS, file_copy_method = clone makes copying a multi-GB
# database near instant; elsewhere it's a full copy. Postgres refuses to copy a database that has
# connections, so this fails while the source is in use.
clone_db() {
  echo "Cloning $1 into $2..."
  psql -X -d postgres -q -v ON_ERROR_STOP=1 \
    -c "SET file_copy_method = clone" \
    -c "CREATE DATABASE \"$2\" TEMPLATE \"$1\" STRATEGY = FILE_COPY"
}

# Copy-on-write copies where the filesystem has them (btrfs, XFS, APFS), plain copies elsewhere.
# Existing files are kept.
clone_files() {
  if cp --help 2>&1 | grep -q reflink; then
    cp -an --reflink=auto "$1" "$2"
  else
    cp -cRpn "$1" "$2" 2>/dev/null || cp -Rpn "$1" "$2"
  fi
}
