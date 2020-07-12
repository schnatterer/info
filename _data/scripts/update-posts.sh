#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

BASEDIR=$(dirname $0)
page=1
while [[ 1 ]]; do

  echo "Querying page $page"
  posts=$(mktemp)
  curl --fail -Lks https://public-api.wordpress.com/rest/v1.1/sites/itaffinity.wordpress.com/posts?page=${page} > ${posts}
  if [[ $(jq '.found' ${posts}) == 0 ]]; then
    echo "Page ${page} returned 0 posts. Exiting."
    break
      # e.g.
    # { "found": 41,
    #  "post": [],
    #  "meta": {
    #    "next_page": "value=2015-02-26T21%3A48%3A46%2B01%3A00&id=546",
    #  }
  fi
    
  # TODO sorting
  
  postIndex=0
  for post in $(jq -r '.posts[] | @base64' ${posts}); do
    _jq() {
      echo ${post} | base64 --decode | jq "$@"
    }

    postDate=$(_jq -r '.date')
    postId=$(_jq -r '.ID')
    postTitle=$(_jq -r '.title')
    postUrl=$(_jq -r '.URL')
    postShortDate="${postDate:0:10}"
    postYear="${postDate:0:4}"
    existingPost=$(yq ".[] | select(.year == $postYear).pubs[] | select(.ID == \"$postId\")" ${BASEDIR}/../publications.yaml)
  
    echo "Processing #$postIndex: $postYear: $postId - $postTitle"
    if [[ -z "$existingPost" ]]; then 
      echo "New post. Adding."
      tmpfile=$(mktemp)
      yq --yaml-output --argjson newPost \
        "{ \
          \"date\": \"$postShortDate\", \
          \"title\": \"$postTitle\", \
          \"ID\": \"$postId\", \
          \"media\": [ \
            { \
              \"type\": \"Blog\", \
              \"medium\": \"IT Affinity Blog\", \
              \"link\": \"$postUrl\", \
              \"lang\": \"EN\" \
            } \
          ] \
        }" \
        ".[] | select(.year == $postYear).pubs += [\$newPost]"  ${BASEDIR}/../publications.yaml \
        |  yq --slurp --yaml-output '.' > ${tmpfile}
         # Each year is printed as separate object (no array); So Slurp them into one
      
      mv ${tmpfile} ${BASEDIR}/../publications.yaml
    fi
    postIndex=$((postIndex+1))
  done
  
  page=$((page+1))
done  
