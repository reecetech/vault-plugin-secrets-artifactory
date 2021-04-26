#!/bin/bash

set -euo pipefail

: ${ARTIFACTORY_URL:?unset}

plugin=vault-artifactory-secrets-plugin

existing=$(vault secrets list -format json | jq -r '."artifactory/"')
if [ "$existing" == "null" ]; then

  set +e
  env | grep VAULT

  # in CI, current container bind mount is rprivate, preventing nested bind mounts
  # instead, copy plugin in to vault container and reload
  if ! vault plugin list secret | grep -q artifactory; then
    echo "Plugin missing from dev plugin dir /vault/plugins... registering manually."
    sha=$(sha256sum plugins/$plugin | cut -d' ' -f1)
    # if plugin is missing, it is assumed this is a CI environment and vault is running in a container
    docker cp plugins/* vault:/vault/plugins
    docker exec vault ls -al /vault/plugins
    vault plugin register -sha256=$sha secret $plugin
    vault plugin list
  fi

  vault secrets enable -path=artifactory $plugin
  set -e

else
  echo
  echo  "Plugin enabled on path 'artifactory/':"
  echo "$existing" | jq
fi

if [ -z "$ARTIFACTORY_BEARER_TOKEN" ]; then
  echo "ARTIFACTORY_BEARER_TOKEN unset, using username/password"
: ${ARTIFACTORY_USERNAME:?unset}
: ${ARTIFACTORY_PASSWORD:?unset}
  vault write artifactory/config base_url=$ARTIFACTORY_URL username=$ARTIFACTORY_USERNAME password=$ARTIFACTORY_PASSWORD ttl=600 max_ttl=600
else
  vault write artifactory/config base_url=$ARTIFACTORY_URL bearer_token=$ARTIFACTORY_BEARER_TOKEN ttl=600 max_ttl=600
fi
