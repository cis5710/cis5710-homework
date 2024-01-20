VERSION=v0

build:
	docker build --target base -t cis5710/hw-base:latest .
	docker tag cis5710/hw-base:latest cis5710/hw-base:$(VERSION)
	docker push cis5710/hw-base:$(VERSION)
	docker push cis5710/hw-base:latest

run:
	docker run -it cis5710/hw-base:latest /bin/bash
