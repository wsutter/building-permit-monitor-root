#!/bin/bash
# Maven Version Helper Scripts for BMad

# Calculate next minor version (e.g., 1.0.0 -> 1.1.0-SNAPSHOT)
calculate_next_minor_version() {
  local current_version="$1"
  local major=$(echo "$current_version" | cut -d. -f1)
  local minor=$(echo "$current_version" | cut -d. -f2)
  echo "${major}.$((minor + 1)).0-SNAPSHOT"
}

# Example usage:
# next_version=$(calculate_next_minor_version "1.0.0")
