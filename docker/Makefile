# This Makefile is for use by course staff in building & running new versions of
# the Docker image. Students do not need to build the container image but should
# instead follow [our Docker instructions](../README.md).

VERSION=v3

build:
	docker buildx build --platform=linux/amd64 --target base -t cis5710/hw-base:latest --file Dockerfile .

push: build
	docker tag cis5710/hw-base:latest cis5710/hw-base:$(VERSION)
	docker push cis5710/hw-base:$(VERSION)
	docker push cis5710/hw-base:latest

rm:
	docker container rm 5710-playground

run:
	docker run -it cis5710/hw-base:latest /bin/bash
