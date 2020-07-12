#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

BASEDIR=$(dirname $0)

i=0
for project in $(yq -r '.projects[].name' ${BASEDIR}/../projects.yaml); do
  git clone --bare http://github.com/${project} tmp
  cd tmp
  firstDate="$(git log --all --author='schnatterer' --reverse --pretty=format:'%as' | head -n1)"
  lastDate="$(git log --all --author='schnatterer' --pretty=format:'%as' | head -n1)"
  nCommits="$(git log --all --author='schnatterer' --pretty=format:'%as' | wc -l)"
  cd ..
  echo ${i}: ${project}, commits from ${firstDate} to ${lastDate}
  tmpfile=$(mktemp)
  yq --arg val ${firstDate} ".projects[$i].commits.from=\$val" ${BASEDIR}/../projects.yaml \
    | jq --arg val ${lastDate} ".projects[$i].commits.to=\$val" \
    | yq --arg val ${nCommits} --yaml-output ".projects[$i].commits.amount=\$val" > ${tmpfile}
  mv ${tmpfile} ${BASEDIR}/../projects.yaml
  rm -rf tmp
  i=$((i+1))
done
