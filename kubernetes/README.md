# Invidious Helm chart

Easily deploy Invidious to Kubernetes.

## Installing Helm chart

Edit `values.yaml` to your liking, especially set `config.hmac_key`. Then install the chart:


```sh
$ helm install invidious ./
```

## Upgrading

```sh
# Upgrading is easy, too!
$ helm upgrade invidious ./
```

## Uninstall

```sh
# Get rid of everything (except database)
$ helm delete invidious

# To also delete the database, remove all invidious-postgresql PVCs
```
