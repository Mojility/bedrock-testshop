#!/bin/sh
case "$PWD" in
  /tmp/starter-integration-sources-083990/bedrock/apps/bedrock)
    MIX_TEST_PARTITION=$(cat /tmp/starter-integration-partition-083990)
    export MIX_TEST_PARTITION
    ;;
esac
exec /home/svetzal/.local/share/mise/installs/elixir/1.20.2-otp-29/bin/mix "$@"
