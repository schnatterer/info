#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

BASEDIR=$(dirname $0)
yq -c '.[]' < $BASEDIR/../pinned-projects.yaml| while read -r item; do
    # Extract and print the attributes of each object
    username=$(echo "$item" | jq -r '.username')
    repo=$(echo "$item" | jq -r '.repo')
    echo "Username: $username"
    echo "Repo: $repo"
     curl --connect-timeout 5 \
    --max-time 30 \
    --retry 10 \
    --retry-delay 1 \
    --retry-max-time 40 \
    --retry-connrefused \
    --retry-all-errors \
"https://github-readme-stats.vercel.app/api/pin/?theme=default&username=$username&repo=$repo" > "$BASEDIR/../../img/${username}_$repo.svg" 
    echo "------------------------"
done

# if some file failed, just git reset it
find . -type f -size 0 -exec git reset {} \;
