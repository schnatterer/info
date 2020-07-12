#!/usr/bin/env bash

BASEDIR=$(dirname $0)

posts=$(mktemp)
curl https://public-api.wordpress.com/rest/v1.1/sites/itaffinity.wordpress.com/posts/ > ${posts}
# TODO paging
# https://public-api.wordpress.com/rest/v1.1/sites/itaffinity.wordpress.com/posts?page=1
# | jq '.meta.next_page' -> Empty = end
#{ "found": 41,
#  "post": [],
#  "meta": {
#    "next_page": "value=2015-02-26T21%3A48%3A46%2B01%3A00&id=546",
#  }
#}
# TODO sorting

i=0
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

  echo "Processing #$i: $postYear: $postId - $postTitle"
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
  i=$((i+1))
done

