#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

BASEDIR=$(dirname $0)

tmpfile=$(mktemp)
yq --yaml-output  ".[].pubs |= (sort_by(.date, .title) | reverse)" ${BASEDIR}/../publications.yaml > ${tmpfile}
mv ${tmpfile} ${BASEDIR}/../publications.yaml