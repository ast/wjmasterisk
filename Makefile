# --- Configuration ---
IMAGE_NAME := sm6wjm/asterisk
TAG        := latest
FULL_IMAGE := $(IMAGE_NAME):$(TAG)

# Paths for mounting
ETC_DIR    := $(shell pwd)/etc-asterisk

.PHONY: help build push run all

help:
	@echo "Asterisk Docker Management"
	@echo "--------------------------"
	@echo "make build   - Build the docker image"
	@echo "make push    - Push the image to the registry"
	@echo "make run     - Run the container locally with mounts"
	@echo "make all     - Build and then Push"

# Build the image locally
build:
	docker build . -t $(FULL_IMAGE)

# Push the image to the registry
push:
	docker push $(FULL_IMAGE)

# Run for local testing
run:
	docker run --rm -it \
		-p 5060:5060/udp -p 5060:5060/tcp -p 5061:5061/tcp \
		-p 10000-10010:10000-10010/udp \
		-v $(ETC_DIR):/etc/asterisk \
		$(FULL_IMAGE)

# Shortcut to do both
all: build push
