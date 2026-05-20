# gh-star-sync

Sync GitHub stars from one account to another using the `gh` CLI.

## Requirements

- [gh](https://cli.github.com/) - GitHub CLI with multiple accounts authenticated
- [gum](https://github.com/charmbracelet/gum) - for interactive account selection (optional)

## Usage

### Interactive (requires gum)

```bash
./gh-star-sync.sh
```

Prompts you to pick source and target accounts, then syncs all stars.

### Non-interactive

```bash
./gh-star-sync.sh <source-account> <target-account>
```

## Setup

Make sure both accounts are authenticated:

```bash
gh auth login  # repeat for each account
gh auth status # verify both appear
```

## What it does

1. Fetches all starred repos from the source account
2. Switches to the target account
3. Stars each repo, skipping any already starred
4. Reports a summary of starred/skipped/failed repos
