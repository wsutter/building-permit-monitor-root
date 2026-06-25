#!/bin/bash
# Git Flow Helper Scripts for BMad
# Ensures Git Flow is initialized and derives versions from epic keys.

# Initialize Git Flow (non-interactive, default branch names)
initialize_git_flow() {
  if ! git config --get gitflow.branch.master > /dev/null; then
    git flow init -d || {
      echo "Git Flow initialization failed. Ensure Git Flow is installed."
      exit 1
    }
  fi
}

# Derive version from epic key (e.g., epic-1 -> 1.0)
derive_version() {
  local epic_key="$1"
  echo "${epic_key//epic-/}" | sed 's/-/.0/g'
}

# Example usage:
# initialize_git_flow
# version=$(derive_version "epic-1")
