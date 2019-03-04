#!/bin/bash

echo "apiVersion: v1";
echo "kind: Secret"
echo "metadata:"
echo "  name: sendgridkey"
echo "type: Opaque"
echo "data:"
echo "  sendgridkey: $1"
