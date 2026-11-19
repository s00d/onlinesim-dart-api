#!/usr/bin/env bash
# Smoke test of the PUBLISHED artifact: pack the package exactly as `dart pub publish` would
# (`--to-archive`, the same step pub.dev's publishing workflow runs), check the archive holds only
# the package files, unpack it, create an empty app that depends on it via `path:`, and run the
# README "Testing" example in it (offline, against MockOnlineSim).
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/onlinesim-smoke.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

(cd "$root" && dart pub publish --to-archive="$tmp/package.tar.gz" --skip-validation)

mkdir -p "$tmp/onlinesim" "$tmp/app/bin"
tar -xzf "$tmp/package.tar.gz" -C "$tmp/onlinesim"
files=$(cd "$tmp/onlinesim" && find . -type f | sed 's#^\./##' | sort)
stray=$(echo "$files" | grep -Ev '^(lib/.+\.dart|example/main\.dart|README\.md|CHANGELOG\.md|LICENSE|pubspec\.yaml|analysis_options\.yaml)$' || true)
if [ -n "$stray" ]; then
  echo "unexpected files in the archive:"
  echo "$stray"
  exit 1
fi
for f in lib/onlinesim.dart example/main.dart README.md CHANGELOG.md LICENSE pubspec.yaml; do
  echo "$files" | grep -qx "$f" || { echo "archive lacks $f"; exit 1; }
done
echo "archive: $(echo "$files" | wc -l | tr -d ' ') files"

cat > "$tmp/app/pubspec.yaml" <<'YAML'
name: smoke_app
publish_to: none
environment:
  sdk: '>=3.0.0 <4.0.0'
dependencies:
  onlinesim:
    path: ../onlinesim
YAML

# The first ```dart block after "## Testing" in the packaged README.
awk '/^## Testing/ { t = 1 } t && /^```dart/ { c = 1; next } c && /^```/ { exit } c { print }' \
  "$tmp/onlinesim/README.md" > "$tmp/app/bin/main.dart"
[ -s "$tmp/app/bin/main.dart" ] || { echo 'README.md has no "## Testing" dart example'; exit 1; }

(cd "$tmp/app" && dart pub get && dart run bin/main.dart) | tee "$tmp/out.txt"
grep -qx 'ok: 123456' "$tmp/out.txt"
echo "README \"Testing\" example from the artifact: ok ($(dart --version 2>&1))"
