#!/bin/sh

exec ssh -oIdentityFile=/tmp/.oc/keys/id.pem -o "StrictHostKeyChecking no" "$@"

