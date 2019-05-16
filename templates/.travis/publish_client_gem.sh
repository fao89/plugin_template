#!/bin/bash

echo "---
:rubygems_api_key: $RUBYGEMS_API_KEY" > ~/.gem/credentials
sudo chmod 600 ~/.gem/credentials

django-admin runserver 24817 >> ~/django_runserver.log 2>&1 &
sleep 5

cd $TRAVIS_BUILD_DIR
export REPORTED_VERSION=$(http :24817/pulp/api/v3/status/ | jq --arg plugin {{ plugin_snake_name }} -r '.versions[] | select(.component == $plugin) | .version')
export DESCRIPTION="$(git describe --all --exact-match `git rev-parse HEAD`)"
if [[ $DESCRIPTION == 'tags/'$REPORTED_VERSION ]]; then
  export VERSION=${REPORTED_VERSION}
else
  export EPOCH="$(date +%s)"
  export VERSION=${REPORTED_VERSION}.dev.${EPOCH}
fi

export response=$(curl --write-out %{http_code} --silent --output /dev/null https://rubygems.org/gems/{{ plugin_snake_name }}_client/versions/$VERSION)

if [ "$response" == "200" ];
then
    exit
fi

cd
git clone https://github.com/pulp/pulp-openapi-generator.git
cd pulp-openapi-generator

sudo ./generate.sh {{ plugin_snake_name }} ruby $VERSION
sudo chown -R travis:travis {{ plugin_snake_name }}-client
cd {{ plugin_snake_name }}-client
gem build {{ plugin_snake_name }}_client
GEM_FILE="$(ls | grep {{ plugin_snake_name }}_client-)"
gem push ${GEM_FILE}
