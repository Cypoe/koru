#!/bin/bash
# Pin the artifacts the transcript can't show: the defined verb persisted to
# the world, and every write landed the fixture's bytes. Then restore.
cd "$test_dir" 2>/dev/null || true
TD="${test_dir:-.}"
fail=0
grep -q 'backup = read(path: src)' "$TD/world/backup.k" || { echo "post: world/backup.k missing composite"; fail=1; }
for f in backup.txt again.txt b-copy.txt; do
    grep -q 'first line of the world' "$TD/files/$f" || { echo "post: files/$f missing fixture bytes"; fail=1; }
done
rm -rf "$TD/world" "$TD/files/backup.txt" "$TD/files/again.txt" "$TD/files/b-copy.txt"
exit $fail
