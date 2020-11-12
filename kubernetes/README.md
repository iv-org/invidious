# Invidious Helm chart

Easily deploy Invidious to Kubernetes.

## Installing Helm chart

```sh
# Build Helm dependencies
$ helm dep build

# Add PostgreSQL init scripts
$ kubectl create configmap invidious-postgresql-init \
  --from-file=../config/sql/channels.sql \
  --from-file=../config/sql/videos.sql \
  --from-file=../config/sql/channel_videos.sql \
  --from-file=../config/sql/users.sql \
  --from-file=../config/sql/session_ids.sql \
  --from-file=../config/sql/nonces.sql \
  --from-file=../config/sql/annotations.sql \
  --from-file=../config/sql/playlists.sql \
  --from-file=../config/sql/playlist_videos.sql

# Install Helm app to your Kubernetes cluster
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
