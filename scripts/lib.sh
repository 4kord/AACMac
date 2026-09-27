repo_slug() {
  if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    echo "$GITHUB_REPOSITORY"
  else
    gh repo view --json nameWithOwner -q .nameWithOwner
  fi
}

fetch_verified() {
  if [[ -f "$3" ]] && echo "$2  $3" | shasum -a 256 -c --status; then return; fi
  curl -fL --retry 3 -o "$3.part" "$1"
  if ! echo "$2  $3.part" | shasum -a 256 -c --status; then
    rm -f "$3.part"
    echo "hash mismatch: $1" >&2
    exit 1
  fi
  mv "$3.part" "$3"
}
