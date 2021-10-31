# Invidious Kubernetes Deployment

This is a plain deployment of Invidious and a PostgreSQL database to Kubernetes
which can easily be customized. It is only designed for personal use (only one
replica, very basic PostgreSQL setup, automatic updates).

## Installing

```sh
# Create a separate namespace for invidious
kubectl create ns invidious
kubectl config set-context --current --namespace=invidious

# Run a PostgreSQL instance
pgpw=$(pwgen -s 32 1)
kubectl create secret generic postgres --from-literal=rootpassword="$pgpw"
kubectl apply -f postgres.yaml

# Run invidious (you may want to copy and edit the config file before; an empty file works fine)
kubectl create configmap invidious --from-file=INVIDIOUS_CONFIG=../config/config.example.yml
kubectl create secret generic invidious --from-literal=INVIDIOUS_DATABASE_URL="postgresql://postgres:$pgpw@postgres/invidious"
kubectl apply -f invidious.yaml
```

### Making it reachable from the web

To make Invidious reachable from the web you also need an Ingress (or
equivalent). This is a basic variant that requires
[cert-manager](https://cert-manager.io/docs/) and something that processes
Ingress objects (like [traefik](https://doc.traefik.io/traefik/)).

```sh
sed s/invidious.example.org/your.invidious.domain/ web.yaml | kubectl apply -f -
```

## Upgrading

### Automatic

The deployment has annotations for [Keel](https://keel.sh) for automatic
updates. Keel can quickly be installed as follows, but you should make yourself
familiar with it if you intend to use it.

```sh
curl 'https://sunstone.dev/keel?namespace=keel' | kubectl apply -f -
```

Note that the deployment is configured to even upgrade to new major versions,
preferring things to break over having an outdated and potentially vulnerable
instance.

### Manual

The `imagePullPolicy` is set to `Always`, so simply restarting the deployment
upgrades Indivious:

```sh
kubectl rollout restart deployment invidious
```

## Uninstall

Simply delete the namespace.
