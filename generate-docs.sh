#!/usr/bin/env bash
#
# Generates the talk documents with the vensas-doc-generator.
#
#   ./generate-docs.sh                  the IT-Tage talk deck
#   ./generate-docs.sh -v               show the full generator output
#
# The generator repository must be beside this repository. Use the environment
# variable DOC_GENERATOR_DIR to give a different path.
#
# The DWX deck (docs/aspire-in-der-praxis-dwx-2026-06-30.html) is hand-written HTML and is not made here.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$REPO_DIR/docs"
GENERATOR_DIR="${DOC_GENERATOR_DIR:-$REPO_DIR/../vensas-doc-generator}"

DECK="aspire-in-practice-it-tage-2026-12-10"

VERBOSE=0
TARGETS=()

for arg in "$@"; do
  case "$arg" in
    -v|--verbose) VERBOSE=1 ;;
    slides|deck)  TARGETS+=("$DECK") ;;
    -h|--help)    sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "Unknown option: $arg. Use -h for help." >&2; exit 2 ;;
  esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=("$DECK")
fi

if [ ! -d "$GENERATOR_DIR" ]; then
  echo "✗ The generator is not at: $GENERATOR_DIR" >&2
  echo "  Set DOC_GENERATOR_DIR to the path of the vensas-doc-generator." >&2
  exit 1
fi
GENERATOR_DIR="$(cd "$GENERATOR_DIR" && pwd)"

failed=0

for name in "${TARGETS[@]}"; do
  yaml="$DOCS_DIR/$name.yaml"
  pdf="$DOCS_DIR/$name.pdf"

  if [ ! -f "$yaml" ]; then
    echo "✗ $name — no input file at $yaml" >&2
    failed=1
    continue
  fi

  printf '→ %s ... ' "$name"

  # The generator must run in its own directory, because it reads its
  # layouts, assets and company configuration from there.
  if [ "$VERBOSE" -eq 1 ]; then
    ( cd "$GENERATOR_DIR" && npm run generate:file -- "$yaml" \
        --output-dir "$DOCS_DIR" --working-dir "$DOCS_DIR" )
    status=$?
  else
    log="$(mktemp)"
    set +e
    ( cd "$GENERATOR_DIR" && npm run generate:file -- "$yaml" \
        --output-dir "$DOCS_DIR" --working-dir "$DOCS_DIR" ) >"$log" 2>&1
    status=$?
    set -e
  fi

  if [ $status -ne 0 ]; then
    echo "FAILED"
    [ "$VERBOSE" -eq 0 ] && sed 's/^/    /' "$log" >&2
    if [ "$VERBOSE" -eq 0 ] && grep -q "Could not find Chrome" "$log"; then
      echo "  Hint: run 'npx puppeteer browsers install chrome' in $GENERATOR_DIR" >&2
    fi
    [ "$VERBOSE" -eq 0 ] && rm -f "$log"
    failed=1
    continue
  fi
  [ "$VERBOSE" -eq 0 ] && rm -f "$log"

  if [ ! -f "$pdf" ]; then
    echo "FAILED — the generator reported success but wrote no PDF"
    failed=1
    continue
  fi

  size="$(du -k "$pdf" | cut -f1)"
  # pdfinfo comes with poppler. Report the page count only if it is installed,
  # because a wrong count is worse than no count.
  if command -v pdfinfo >/dev/null 2>&1; then
    pages="$(pdfinfo "$pdf" 2>/dev/null | awk '/^Pages:/ { print $2 }')"
    echo "ok (${pages:-?} pages, ${size} KB)"
  else
    echo "ok (${size} KB)"
  fi
done

if [ $failed -ne 0 ]; then
  echo
  echo "✗ At least one document failed." >&2
  exit 1
fi

echo
echo "✓ Written to $DOCS_DIR"
