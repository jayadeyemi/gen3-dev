docker pull ubuntu:25.04
# From the directory containing Dockerfile + entrypoint.sh
docker build -t gen3-ack-deploy .

docker run --rm -it \
  --name gen3-ack-deploy \
  -v "$(pwd):/workspace" \
  gen3-ack-deploy

