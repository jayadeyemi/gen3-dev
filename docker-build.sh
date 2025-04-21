docker pull ubuntu:25.04
# From the directory containing Dockerfile + entrypoint.sh
docker build --no-cache -t gen3-ack-deploy .

docker run --rm -it \
  --name gen3-ack-deploy \
  -file ../Dockerfile \
  -v "$(pwd):/workspace" \
  gen3-ack-deploy

