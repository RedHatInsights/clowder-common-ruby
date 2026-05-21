#!/usr/bin/env sh

if [ "$(command -v wget)" ]; then
  wget https://raw.githubusercontent.com/RedHatInsights/clowder/master/controllers/cloud.redhat.com/config/schema.json -O ./bin/schema.json
else
  curl https://raw.githubusercontent.com/RedHatInsights/clowder/master/controllers/cloud.redhat.com/config/schema.json -o ./bin/schema.json
fi

./bin/json_schema_ruby -o ./lib/clowder-common-ruby/types.rb ./bin/schema.json
