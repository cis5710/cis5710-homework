# This Makefile is for use by course staff in building & running new versions of
# the Docker image. Students do not need to build the container image but should
# instead follow [our Docker instructions](../README.md).

GS_VERSION=v2

build-gs:
	docker buildx build --platform=linux/amd64 --target base -t cis5710/hw-base-gradescope:latest --file Dockerfile.gradescope .

push-gs: build-gs
	docker tag cis5710/hw-base-gradescope:latest cis5710/hw-base-gradescope:$(GS_VERSION)
	docker push cis5710/hw-base-gradescope:$(GS_VERSION)
	docker push cis5710/hw-base-gradescope:latest

ARM_VERSION=v1

build-arm:
	docker buildx build --target base -t cis5710/hw-base-arm:latest --file Dockerfile.arm64 .

push-arm: build-arm
	docker tag cis5710/hw-base-arm:latest cis5710/hw-base-arm:$(ARM_VERSION)
	docker push cis5710/hw-base-arm:$(ARM_VERSION)
	docker push cis5710/hw-base-arm:latest

rm:
	docker container rm 5710-playground

run:
	docker run -it cis5710/hw-base:latest /bin/bash
