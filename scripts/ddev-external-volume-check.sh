#!/bin/bash
# Checks the DDEV features that depend on bind mounts and Mutagen, for a running project.
# Usage: ddev-external-volume-check.sh <project-dir> <upload-dir-relative-to-project-root>
#   e.g. ddev-external-volume-check.sh ~/tmp/linked-proj public/files
# Takes a database snapshot first and restores it at the end, because the pull test replaces the database.
# Creates and drops a database named bmtestdb, and writes .ddev/providers/bmtest.yaml temporarily.
set -u
DIR=$1; UP=$2; T=$(date +%s)
cd "$DIR" || exit 1
ok() { echo "  PASS: $*"; }; bad() { echo "  FAIL: $*"; }
echo "== cwd=$PWD  project=$(ddev describe -j | jq -r .raw.name)"
ddev mutagen st -l 2>/dev/null | grep -E '^\s*URL: /|^Status' | sed 's/^\s*/  /'
ddev describe -j | jq -r '"  approot=" + .raw.approot'

echo "-- bind mount, upload dir ($UP)"
mkdir -p "$UP" && echo "host-$T" > "$UP/bm-host-$T.txt"
c=$(ddev exec cat "/var/www/html/$UP/bm-host-$T.txt" 2>&1); [ "$c" = "host-$T" ] && ok "host->container" || bad "host->container: $c"
ddev exec "echo ctr-$T > /var/www/html/$UP/bm-ctr-$T.txt"
[ "$(cat "$UP/bm-ctr-$T.txt" 2>&1)" = "ctr-$T" ] && ok "container->host" || bad "container->host"
rm -f "$UP/bm-host-$T.txt" "$UP/bm-ctr-$T.txt"

echo "-- mutagen-synced file"
echo "sync-$T" > "bm-sync-$T.txt"; ddev mutagen sync >/dev/null 2>&1
[ "$(ddev exec cat /var/www/html/bm-sync-$T.txt 2>&1)" = "sync-$T" ] && ok "host->container via Mutagen" || bad "Mutagen sync"
rm -f "bm-sync-$T.txt"

echo "-- snapshot"
ddev snapshot --name "bmtest-$T" >/dev/null 2>&1 && ls .ddev/db_snapshots | grep -q "bmtest-$T" && ok "snapshot bmtest-$T on host" || bad "snapshot"

echo "-- export-db / import-db"
ddev export-db --file="$HOME/tmp/bmtest-$T.sql.gz" >/dev/null 2>&1 && [ -s "$HOME/tmp/bmtest-$T.sql.gz" ] && ok "export-db ($(du -h "$HOME/tmp/bmtest-$T.sql.gz" | cut -f1))" || bad "export-db"
ddev import-db --database=bmtestdb --file="$HOME/tmp/bmtest-$T.sql.gz" >/dev/null 2>&1 && n=$(ddev mysql bmtestdb -N -e 'show tables' 2>/dev/null | wc -l) && [ "$n" -gt 0 ] && ok "import-db into bmtestdb ($n tables)" || bad "import-db"
ddev mysql -e 'DROP DATABASE IF EXISTS bmtestdb' >/dev/null 2>&1
rm -f "$HOME/tmp/bmtest-$T.sql.gz"

echo "-- import-files"
mkdir -p "$HOME/tmp/bmfiles-$T" && echo "imp-$T" > "$HOME/tmp/bmfiles-$T/bm-imported-$T.txt" && tar -czf "$HOME/tmp/bmfiles-$T.tgz" -C "$HOME/tmp/bmfiles-$T" .
ddev import-files --source="$HOME/tmp/bmfiles-$T.tgz" >/dev/null 2>&1 && [ "$(ddev exec cat /var/www/html/$UP/bm-imported-$T.txt 2>&1)" = "imp-$T" ] && ok "import-files visible in container" || bad "import-files"
rm -rf "$HOME/tmp/bmfiles-$T" "$HOME/tmp/bmfiles-$T.tgz" "$UP/bm-imported-$T.txt"

echo "-- pull (custom provider, writes .ddev/.downloads in the web container)"
cat > .ddev/providers/bmtest.yaml <<'YAML'
auth_command:
  command: "true"
db_pull_command:
  command: |
    set -eu -o pipefail
    mkdir -p /var/www/html/.ddev/.downloads
    printf 'CREATE TABLE pulltest (id int); INSERT INTO pulltest VALUES (42);\n' | gzip > /var/www/html/.ddev/.downloads/db.sql.gz
  service: web
files_pull_command:
  command: |
    set -eu -o pipefail
    mkdir -p /var/www/html/.ddev/.downloads/files
    echo pulled > /var/www/html/.ddev/.downloads/files/bm-pulled.txt
  service: web
YAML
ddev pull bmtest -y >"$HOME/tmp/bmpull-$T.log" 2>&1; rc=$?
v=$(ddev mysql -N -e 'select id from pulltest' 2>/dev/null)
[ $rc -eq 0 ] && [ "$v" = 42 ] && ok "pull db" || { bad "pull db rc=$rc v=$v"; tail -5 "$HOME/tmp/bmpull-$T.log"; }
[ "$(ddev exec cat /var/www/html/$UP/bm-pulled.txt 2>&1)" = pulled ] && [ -f "$UP/bm-pulled.txt" ] && ok "pull files on host and in container" || bad "pull files"
rm -f .ddev/providers/bmtest.yaml "$UP/bm-pulled.txt" "$HOME/tmp/bmpull-$T.log"

echo "-- snapshot restore"
ddev snapshot restore "bmtest-$T" >/dev/null 2>&1; v=$(ddev mysql -N -e "show tables like 'pulltest'" 2>/dev/null)
[ -z "$v" ] && ok "restored, pulltest gone" || bad "restore"
ddev snapshot --cleanup --name "bmtest-$T" -y >/dev/null 2>&1 || rm -f .ddev/db_snapshots/bmtest-$T*
echo "-- mutagen-diagnose"; ddev utility mutagen-diagnose 2>&1 | grep -E '✓|⚠|✗' | head -5
