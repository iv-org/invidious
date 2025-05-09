docker buildx build --platform=linux/x86_64 --tag=invidious . && docker tag invidious main.local:20000/invidious/invidious
docker push main.local:20000/invidious/invidious
docker rmi $(docker images main.local:20000/invidious/invidious -q) --force
echo "Finished."
