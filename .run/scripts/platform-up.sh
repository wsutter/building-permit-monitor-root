#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

podman compose -f platform/compose/docker-compose.yml up -d
