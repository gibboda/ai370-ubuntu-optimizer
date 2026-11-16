#!/usr/bin/env bash
# Copy reports/latest into runner-owned staging (no root after sudo drop).
set -euo pipefail

workspace="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
dest="${RUNNER_TEMP:?RUNNER_TEMP is required}/portable-test-reports"
source_dir="${workspace}/reports/latest"

rm -rf "$dest"
mkdir -p "$dest"

if [[ -d "$source_dir" && ! -L "$source_dir" ]]; then
  cp -a "$source_dir/." "$dest/"
  echo "Staged reports for artifact upload at ${dest}"
else
  echo "No reports/latest directory to stage"
fi