#!/bin/bash

echo "apiVersion: v1";
echo "kind: Secret"
echo "metadata:"
echo "  name: fcmkey"
echo "type: Opaque"
echo "data:"
echo "  fcmkey: $1"
