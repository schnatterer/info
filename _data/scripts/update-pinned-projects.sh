#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

BASEDIR=$(dirname "$0")
ABSOLUTE_BASEDIR="$( cd "${BASEDIR}" && pwd )"

PAT_1=$1

GRS_COMMIT=8994937
TMP_DIR=$(mktemp -d)
git clone https://github.com/anuraghazra/github-readme-stats --single-branch "$TMP_DIR/github-readme-stats"
cd "$TMP_DIR/github-readme-stats"
git checkout "$GRS_COMMIT"

# Use jq to move express from devDependencies to dependencies
jq '.dependencies.express = .devDependencies.express | del(.devDependencies.express)' package.json > package.tmp.json
mv package.tmp.json package.json
echo "Installing production dependencies..."
npm install

cleanup() {
    echo "Container stopping, shutting down Node.js..."
    kill -TERM "$pid" 2>/dev/null
    wait "$pid" || true
    exit 0
}
trap cleanup SIGTERM SIGINT

echo "Starting the server..."
export PAT_1
node express.js &


yq -c '.[]' < "$ABSOLUTE_BASEDIR"/../pinned-projects.yaml | while read -r item; do
    # Extract and print the attributes of each object
    username=$(echo "$item" | jq -r '.username')
    repo=$(echo "$item" | jq -r '.repo')
    echo "Username: $username"
    echo "Repo: $repo"

    url="http://localhost:9000/api/pin/?theme=default&username=$username&repo=$repo"
    target="$ABSOLUTE_BASEDIR/../../img/${username}_$repo.svg"
    tmpfile=$(mktemp "${target}.tmp.XXXXXX")

    # Download into a temporary file; on HTTP error, exit non‑zero and keep existing target intact
    if curl --connect-timeout 5 \
        --max-time 30 \
        --retry 10 \
        --retry-delay 1 \
        --retry-max-time 40 \
        --retry-connrefused \
        --retry-all-errors \
        --fail-with-body \
        --silent \
        --show-error \
        --output "$tmpfile" \
        "$url"; then
        mv "$tmpfile" "$target"
    else
        echo "Error: Failed to download SVG for $username/$repo from $url. Keeping existing file: $target" >&2
        rm -f "$tmpfile"
        exit 1
    fi
    echo "------------------------"
done
