#!/bin/sh
case "$PWD" in
  /tmp/starter-c8-permissions/bedrock/apps/bedrock)
    MIX_TEST_PARTITION=$(cat /tmp/starter-c8-permissions/partition)
    export MIX_TEST_PARTITION
    ;;
esac
exec /home/svetzal/.local/share/mise/installs/elixir/1.20.2-otp-29/bin/mix "$@"
