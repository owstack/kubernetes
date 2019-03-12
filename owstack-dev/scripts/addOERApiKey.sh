#!/bin/bash

OERKEY=`echo $1 | base64`

echo "apiVersion: v1";
echo "kind: Secret"
echo "metadata:"
echo "  name: oerkey"
echo "type: Opaque"
echo "data:"
echo "  oerkey: $OERKEY"
