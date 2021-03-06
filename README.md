# OWStack on GKE

Features:
- Deploy OWStack to Kubernetes on Google Cloud
- Ambassador API Gateway to expose micro-services as public routes behind a single IP
- SSL Cert automation for Ambassador via cert-manager and letsencrypt.org
- Highly-available, redundant, load-balanced services

## GKE Setup

Login at https://console.cloud.google.com and create a kubernetes cluster. Use Ubuntu as the OS to gain access to required disk features.
```sh
# Setup gcloud command line tools
# https://cloud.google.com/sdk/docs/quickstarts
# https://cloud.google.com/kubernetes-engine/docs/quickstart

# Authenticate kubectl with your new cluster
gcloud container clusters get-credentials [clustername]

# Deploy SSD Storage class for GKE
kubectl apply -f gke/ssd-storage.yml
```

## Deploy Core Services
```sh
# Create RPC Secret
./scripts/generateRPCSecret.sh | kubectl apply -f -

# these services may take hours or days to initialize
kubectl apply -f deployment/bitcoin.yml
kubectl apply -f services/bitcoin.yml

kubectl apply -f deployment/bitcoin-abc.yml
kubectl apply -f services/bitcoin-abc.yml

kubectl apply -f deployment/litecoin.yml
kubectl apply -f services/litecoin.yml
```

## Deploy the Mongo cluster
```sh
# Create a 3 node replica set
kubectl apply -f deployment/mongodb.yml
kubectl apply -f services/mongodb.yml

# connect to mongo shell in container mongo-0
kubectl exec -it mongo-0 mongo
```
```javascript
>   rs.initiate(
        {
            _id: "rs0",
            version: 1,
            members: [
            { _id: 0, host : "mongo-0.mongo:27017" },
            { _id: 1, host : "mongo-1.mongo:27017" },
            { _id: 2, host : "mongo-2.mongo:27017" }
            ]
        }
    )
> exit
```

## Setup API Gateway

https://getambassador.io

Ambassador integrates with kubernetes so that deployments can all appear behind a single public IP address and SSL certificate. Individual service routes are mapped in the service YAML.

As of version Ambassador 0.50.0 ...

```sh
# RBAC fix for GKE
kubectl apply clusterrolebinding my-cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud info --format="value(config.account)")

# Install Ambassador
kubectl apply -f https://getambassador.io/yaml/ambassador/ambassador-rbac.yaml

# Create Loadbalancer for Ambassador, use this public IP for DNS entry for your domain
kubectl apply -f services/ambassador.yml

# Create cert-manager namespace
kubectl create namespace cert-manager

# Disable resource validation on the cert-manager namespace
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Install the CustomResourceDefinition resources
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml

# Install cert-manager itself
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/cert-manager.yaml

# Setup ACME Issuers for letsencrypt.org
kubectl apply -f cert-manager/letsencrypt.yml

# Create Certificate Resource
kubectl apply -f cert-manager/certificate.yml

# ACME Challenge setup
# The steps below add the route `/.well-known/acme-challenge` - This route allows the ACME http01 verification to check ownership of the domain.

#### 1. Obtain ACME domain and token
# After applying the last 2 YAML manifests, you will notice that cert-manager has spun up a temporary pod named cm-acme-http-solver-xxxx but no certificate has been issued. These values show as labels on the GKE container.

#### 2. Setup ACME challenge service
./scripts/addAcmeDomainAndToken.sh YOUR_DOMAIN_ID YOUR_DOMAIN_TOKEN | kubectl apply -f -

#### 3. Verify ambassador-certs secret exists
kubectl get secrets

#### 4. Enable TLS in Ambassador
kubectl patch service ambassador -p "{\"metadata\":{\"annotations\":{\"date\":\"`date +'%s'`\",\"getambassador.io/config\":\"---\\napiVersion: ambassador/v0\\nkind:  Module\\nname:  tls\\nconfig:\\n  server:\\n    enabled: True\\n    redirect_cleartext_from: 80\\n\"}},\"spec\":{\"ports\":[{\"name\":\"http\",\"port\":80,\"protocol\":\"TCP\",\"targetPort\":80},{\"name\":\"https\",\"port\":443,\"protocol\":\"TCP\",\"targetPort\":443}]}}"
```

## Deploy rate service
The OWStack rate service maintains an in-memory copy of the orderbooks from multiple exchanges and can combine them into a virtual orderbook at query time.

```sh
# Setup OER Rate Service https://openexchangerates.org/signup/free
./scripts/addOERApiKey.sh REPLACEWITHYOURAPIKEY | kubectl apply -f -

# /api/rates
kubectl apply -f deployment/rates.yml
kubectl apply -f services/rates.yml
```

## Deploy blockchain explorer APIs
```sh
# /api/explorer/btc
kubectl apply -f deployment/btc-explorer-api.yml
kubectl apply -f services/btc-explorer-api.yml

# /api/explorer/bch
kubectl apply -f deployment/bch-explorer-api.yml
kubectl apply -f services/bch-explorer-api.yml

# /api/explorer/ltc
kubectl apply -f deployment/ltc-explorer-api.yml
kubectl apply -f services/ltc-explorer-api.yml
```

## Deploy blockchain explorer UIs
```sh
# /explorer/btc
kubectl apply -f deployment/btc-explorer-ui.yml
kubectl apply -f services/btc-explorer-ui.yml

# /explorer/bch
kubectl apply -f deployment/bch-explorer-ui.yml
kubectl apply -f services/bch-explorer-ui.yml

# /explorer/ltc
kubectl apply -f deployment/ltc-explorer-ui.yml
kubectl apply -f services/ltc-explorer-ui.yml
```

## Deploy wallet services

```sh
# blockchain monitors for wallets
kubectl apply -f deployment/wallet-service-chain-btc.yml
kubectl apply -f deployment/wallet-service-chain-bch.yml
kubectl apply -f deployment/wallet-service-chain-ltc.yml

# rate monitor for wallets
kubectl apply -f deployment/wallet-service-rates.yml

# cluster lock service for wallets
kubectl apply -f deployment/wallet-service-locker.yml
kubectl apply -f services/wallet-service-locker.yml

# cluster pub/sub for wallets
kubectl apply -f deployment/wallet-service-messenger.yml
kubectl apply -f services/wallet-service-messenger.yml

# /api/ws
kubectl apply -f deployment/wallet-service-wallets.yml
kubectl apply -f services/wallet-service-wallets.yml

# Sendgrid Email Notifications
./scripts/addSendgridApiKey.sh REPLACEWITHYOURAPIKEY | kubectl apply -f -
kubectl apply -f deployments/wallet-service-email.yml

# Google FCM Push Notifications
./scripts/addGoogleFCMKey.sh REPLACEWITHYOURAPIKEY | kubectl apply -f -
kubectl apply -f deployments/wallet-service-push.yml
```
