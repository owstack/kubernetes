#!/bin/bash

USERNAME=`echo -n 'owstack' | base64`
PASSWORD=`openssl rand -base64 32 | base64`

echo "apiVersion: v1";
echo "kind: Secret"
echo "metadata:"
echo "  name: rpcsecret"
echo "type: Opaque"
echo "data:"
echo "  username: $USERNAME"
echo "  password: $PASSWORD"
