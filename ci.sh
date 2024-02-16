#!/bin/bash

PKG_NAME="foundry-js"

# Define the URL to fetch and the initial page number
URL="https://api.github.com/repos/foundry-rs/foundry/releases?per_page=100&page="
PAGE=1

# Define an empty array to hold the tag names
TAGS=()

# Loop until we've fetched all the pages
while true; do
  # Fetch the current page and parse the JSON response
  RESPONSE=$(curl -s "${URL}${PAGE}")
  TAGS_JSON=$(echo "${RESPONSE}" | jq -r '.[].tag_name')

  # If the response is empty, we're done
  if [[ "${TAGS_JSON}" == "" ]]; then
    break
  fi

  # Extract the tag names from the JSON and add them to the array
  while read -r TAG; do
    TAGS+=("${TAG}")
  done <<< "${TAGS_JSON}"

  # Increment the page number
  ((PAGE++))
done

# get dist tags of the package
DIST_TAGS=$(npm view ${PKG_NAME} dist-tags --json | jq keys)
# shellcheck disable=SC2207
DIST_TAGS=($(echo "${DIST_TAGS}" | jq -r '.[]'))

NPM_PUSH_TAG=()
#for tag in "${TAGS[@]}"; do
#  # shellcheck disable=SC2199
#  # shellcheck disable=SC2076
#  if [[ ! " ${DIST_TAGS[@]} " =~ " ${tag} " ]]; then
#    NPM_PUSH_TAG+=("${tag}")
#  fi
#done

if { LATEST_VERSION=$(npm view ${PKG_NAME} versions --json); } then
  LATEST_VERSION=$(echo "${LATEST_VERSION}" | jq -r '.[-1]')
else
  LATEST_VERSION="1.0.0"
fi

npm version "${LATEST_VERSION}" --no-git-tag-version --allow-same-version

NPM_PUSH_TAG+=("nightly")
for tag in "${NPM_PUSH_TAG[@]}"; do
  echo "Publishing tag ${tag}"
  npm version patch --no-git-tag-version
  npm ci
  npm run download --foundry_version="${tag}" --foreground-scripts --loglevel=verbose
  RELEASE_VERSION=$(bash bin/forge-delegate.sh -V | awk '{print $2}')
  RELEASE_DIST=$(echo "${tag}" | awk '{split($0,array,"-"); print array[1]}')
  RELEASE_HASH=$(echo "${tag}" | awk '{split($0,array,"-"); print array[2]}' | awk '{print substr($0,0,6)}')
  if [[ -z "${RELEASE_HASH}" ]]; then
    RELEASE_DIST_TAG="${RELEASE_VERSION}-${RELEASE_DIST}"
  else
    RELEASE_DIST_TAG="${RELEASE_VERSION}-${RELEASE_DIST}+${RELEASE_HASH}"
  fi
  echo "Publishing to dist-tag ${RELEASE_DIST_TAG}"
  npm publish --tag "${RELEASE_DIST_TAG}"
  npm run clean
done
