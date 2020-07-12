#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

BASEDIR=$(dirname $0)

tmpfile=$(mktemp)
yq '.projects |= (sort_by(.commits.to) | reverse)' ${BASEDIR}/../projects.yaml | \
yq --arg val $(date +%Y-%m-%d) --yaml-output ".updated=\$val"  > ${tmpfile}
 
mv ${tmpfile} ${BASEDIR}/../projects.yaml
