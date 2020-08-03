#!/usr/bin/env bash

set -o nounset -o pipefail
# Leads to mysterious failures after firstDate=... 
#set -o errexit 

set -x
BASEDIR=$(dirname $0)

i=0
for project in $(yq -r '.projects[].name' ${BASEDIR}/../projects.yaml); do
  tmpdir=$(mktemp -d)
  git clone --bare http://github.com/${project} ${tmpdir}
  cd ${tmpdir}
  firstDate="$(git log --all --author='schnatterer' --reverse --pretty=format:'%as' | head -n1)"
  lastDate="$(git log --all --author='schnatterer' --pretty=format:'%as' | head -n1)"
  nCommits="$(git log --all --author='schnatterer' --pretty=format:'%as' | wc -l)"
  cd -
  rm -rf ${tmpdir}
  echo ${i}: ${project}, commits from ${firstDate} to ${lastDate}
  tmpfile=$(mktemp)
  yq --arg val ${firstDate} ".projects[$i].commits.from=\$val" ${BASEDIR}/../projects.yaml \
    | jq --arg val ${lastDate} ".projects[$i].commits.to=\$val" \
    | yq --arg val ${nCommits} --yaml-output ".projects[$i].commits.amount=\$val" > ${tmpfile}
  mv "${tmpfile}" "${BASEDIR}/../projects.yaml"
  rm -rf tmp
  i=$((i+1))
done
