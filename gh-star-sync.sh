#!/usr/bin/env bash
set -euo pipefail

# Sync GitHub stars from one account to another using gh CLI.
# Requires: gh CLI with both accounts authenticated (gh auth login),
#           and gum (github.com/charmbracelet/gum) for interactive prompts.
#
# Usage:
#   ./gh-star-sync.sh              # interactive mode (gum prompts)
#   ./gh-star-sync.sh source target # non-interactive mode

# --- Parse available gh accounts (only successfully authenticated ones) ---
get_accounts() {
  local status_output
  status_output=$(gh auth status 2>&1 || true)
  echo "$status_output" \
    | awk '/✓ Logged in.*account/ { for(i=1;i<=NF;i++) if($i=="account") print $(i+1) }' \
    | sed 's/ *(.*$//'
}

ACCOUNTS=$(get_accounts)

if [[ -z "$ACCOUNTS" ]]; then
  echo "Error: No authenticated GitHub accounts found."
  echo "Run 'gh auth login' to add accounts."
  exit 1
fi

ACCOUNT_COUNT=$(echo "$ACCOUNTS" | wc -l | tr -d ' ')

if [[ "$ACCOUNT_COUNT" -lt 2 ]]; then
  echo "Error: Need at least 2 authenticated accounts to sync stars."
  echo "Found: $ACCOUNTS"
  echo "Run 'gh auth login' to add another account."
  exit 1
fi

# --- Pick source and target accounts ---
if [[ $# -ge 2 ]]; then
  # Non-interactive mode
  SOURCE_ACCOUNT="$1"
  TARGET_ACCOUNT="$2"
else
  # Interactive mode with gum
  if ! command -v gum &>/dev/null; then
    echo "Error: gum is not installed. Install with: brew install gum"
    echo "Or pass accounts as arguments: $0 <source> <target>"
    exit 1
  fi

  echo "Select the SOURCE account (copy stars FROM):"
  SOURCE_ACCOUNT=$(echo "$ACCOUNTS" | gum choose --header "Source account")

  # Filter out source from target options
  TARGET_OPTIONS=$(echo "$ACCOUNTS" | grep -v "^${SOURCE_ACCOUNT}$")

  echo "Select the TARGET account (copy stars TO):"
  TARGET_ACCOUNT=$(echo "$TARGET_OPTIONS" | gum choose --header "Target account")
fi

# --- Confirm ---
if command -v gum &>/dev/null; then
  gum style \
    --border rounded \
    --padding "0 1" \
    --border-foreground 212 \
    "Stars: $SOURCE_ACCOUNT -> $TARGET_ACCOUNT"

  gum confirm "Proceed with syncing stars?" || exit 0
fi

# --- Fetch stars from source ---
echo "==> Fetching starred repos from: $SOURCE_ACCOUNT"
gh auth switch --user "$SOURCE_ACCOUNT"

STARRED_REPOS=$(gh api /user/starred \
  --paginate \
  --jq '.[].full_name')

REPO_COUNT=$(echo "$STARRED_REPOS" | wc -l | tr -d ' ')
echo "==> Found $REPO_COUNT starred repos"

# --- Apply stars to target ---
echo "==> Switching to target account: $TARGET_ACCOUNT"
gh auth switch --user "$TARGET_ACCOUNT"

echo "==> Starring repos from target account..."

SUCCESS=0
FAILED=0
ALREADY=0

while IFS= read -r repo; do
  [[ -z "$repo" ]] && continue

  if gh api "/user/starred/$repo" --silent 2>/dev/null; then
    ((ALREADY++))
    echo "  [skip] $repo (already starred)"
  else
    if gh api "/user/starred/$repo" --method PUT --silent 2>/dev/null; then
      ((SUCCESS++))
      echo "  [star] $repo"
    else
      ((FAILED++))
      echo "  [fail] $repo"
    fi
  fi
done <<< "$STARRED_REPOS"

# --- Summary ---
echo ""
if command -v gum &>/dev/null; then
  gum style \
    --border rounded \
    --padding "0 1" \
    --border-foreground 76 \
    "Done!" \
    "  Starred: $SUCCESS" \
    "  Skipped: $ALREADY (already starred)" \
    "  Failed:  $FAILED"
else
  echo "==> Done!"
  echo "    Starred: $SUCCESS"
  echo "    Skipped: $ALREADY (already starred)"
  echo "    Failed:  $FAILED"
fi
