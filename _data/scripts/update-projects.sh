#!/usr/bin/env bash

set -o nounset -o pipefail
set -o errexit

BASEDIR=$(dirname "$0")
TOKEN=$1

set -x

function main() {
  fetchProjects
  updateProjects
}

function fetchProjects() {

  if [[ -z "${TOKEN}" ]]; then
    echo "WARNING: No GitHub token passed. Skipping fetch projects. "
  fi
  ignoreProjects=($(yq -r '.ignored[] | @sh' "${BASEDIR}"/../projects.yaml))

  # More contributionTypes:  ISSUE, PULL_REQUEST, REPOSITORY
  # https://docs.github.com/en/graphql/reference/interfaces#node
  # https://docs.github.com/en/graphql/reference/objects#user
  projects=$(curl --fail -Lks -H "Authorization: bearer $TOKEN" -X POST -d " \
             { \
               \"query\": \
                \" \
                  query { \
                           viewer { \
                            repositoriesContributedTo(first: 100, contributionTypes: [COMMIT], includeUserRepositories:true, privacy: PUBLIC) { \
                              totalCount \
                              nodes { \
                                nameWithOwner \
                                description \
                              } \
                              pageInfo { \
                                endCursor \
                                hasNextPage \
                              } \
                            } \
                          } \
                        } \
                \" \
             } \
            " https://api.github.com/graphql)

  echo "Projects=${projects}"
  if [[ $(jq 'has("errors")' <<< "${projects}") == "true" ]]; then
    echo "GitHub query returned error"
    jq '.errors[].message' <<< "${projects}"
    exit 1
  fi

  # TODO if necessary implement pagination
  [[ $(echo "$projects" | jq -r '.data.viewer.repositoriesContributedTo.pageInfo.hasNextPage') == 'true' ]] && (echo "Pagination not implemented " && exit 1)

  for project in $(echo "${projects}" | jq -r '.data.viewer.repositoriesContributedTo.nodes[] | @base64'); do
    _jq() {
      echo "${project}" | base64 --decode | jq "$@"
    }
    name=$(_jq -r '.nameWithOwner')
    description=$(_jq -r '.description')

    # Check if in array (as list -SC2199; literally, no regex - SC2076). 
    # shellcheck disable=SC2199
    # shellcheck disable=SC2076
    if [[ " ${ignoreProjects[@]} " =~ "${name}" ]]; then
      echo "Skipping project because on ignore list: $name"
      continue
    fi

    existingProject=$(yq ".projects[] | select(.name == \"$name\")" "${BASEDIR}"/../projects.yaml)
  
    # TODO we could update the descriptions for existing projects
    if [[ -z "$existingProject" ]]; then
      echo "New project. Adding - $name"
      tmpfile=$(mktemp)
      
      yq --yaml-output --argjson newProject \
        "{ \
          \"name\": \"$name\", \
          \"type\": \"GitHub\", \
          \"description\": \"$description\", \
          \"technologies\": \"\", \
          \"contribution\": \"Contributor\" \
        }" \
        ".projects += [\$newProject]"  "${BASEDIR}"/../projects.yaml \
        |  yq --yaml-output '.' > "${tmpfile}"
      mv "${tmpfile}" "${BASEDIR}"/../projects.yaml
    fi

  done
}

function updateProjects() {
  i=0
  for project in $(yq -r '.projects[].name' "${BASEDIR}"/../projects.yaml); do
    tmpdir=$(mktemp -d)
    git clone --bare http://github.com/${project}/ "${tmpdir}"
    cd "${tmpdir}" || exit
    # Avoid failures after firstDate=... using || true
    # https://unix.stackexchange.com/a/580119/
    firstDate="$(git --no-pager log --all --author='schnatterer' --reverse --pretty=format:'%as' | head -n1 || true)"
    lastDate="$(git --no-pager log --all --author='schnatterer' --pretty=format:'%as' | head -n1 || true)"
    nCommits="$(git --no-pager log --all --author='schnatterer' --pretty=format:'%as' | wc -l)"
    # Last line does not have a line break and therefore is not counted
    nCommits=$((nCommits + 1))
    cd - || exit
    rm -rf "${tmpdir}"
    echo ${i}: "${project}", commits from "${firstDate}" to "${lastDate}"
    tmpfile=$(mktemp)
    yq --arg val "${firstDate}" ".projects[$i].commits.from=\$val" "${BASEDIR}"/../projects.yaml |
      jq --arg val "${lastDate}" ".projects[$i].commits.to=\$val" |
      yq --arg val "${nCommits}" --yaml-output ".projects[$i].commits.amount=\$val" >"${tmpfile}"
    mv "${tmpfile}" "${BASEDIR}/../projects.yaml"
    rm -rf tmp
    i=$((i + 1))
  done
}

main "$@"
