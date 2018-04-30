#!/bin/bash

echo "apiVersion: v1";
echo "kind: Secret"
echo "metadata:"
echo "  name: oerkey"
echo "type: Opaque"
echo "data:"
echo "  oerkey: $1"
