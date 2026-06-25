#!/bin/bash
# Maven Version Helper Scripts for BMad

# Calculate next minor version (e.g., 1.0.0 -> 1.1.0-SNAPSHOT)
calculate_next_minor_version() {
  local current_version="$1"
  local major=$(echo "$current_version" | cut -d. -f1)
  local minor=$(echo "$current_version" | cut -d. -f2)
  echo "${major}.$((minor + 1)).0-SNAPSHOT"
}

# Calculate next patch version (e.g., 1.0.0 -> 1.0.1-SNAPSHOT)
calculate_next_patch_version() {
  local current_version="$1"
  local major=$(echo "$current_version" | cut -d. -f1)
  local minor=$(echo "$current_version" | cut -d. -f2)
  local patch=$(echo "$current_version" | cut -d. -f3 | cut -d- -f1)
  echo "${major}.${minor}.$((patch + 1))-SNAPSHOT"
}

# Example usage:
# next_minor=$(calculate_next_minor_version "1.0.0")
# next_patch=$(calculate_next_patch_version "1.0.0")
