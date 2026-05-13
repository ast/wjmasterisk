# --- Configuration ---
image_name        := "sm6wjm/asterisk"
tag               := "latest"
full_image        := image_name + ":" + tag
asterisk_version  := "23.3.0"

etc_dir := justfile_directory() / "etc-asterisk"

# List available recipes
default:
    @just --list

# Build the image locally (override version: `just build 23.3.0`)
build version=asterisk_version:
    docker build --build-arg ASTERISK_VERSION={{version}} . -t {{full_image}}

# Push the image to the registry
push:
    docker push {{full_image}}

# Lint the Dockerfile with hadolint (runs RUN blocks through ShellCheck)
lint:
    docker run --rm -i hadolint/hadolint < Dockerfile

# Boot Asterisk against ./etc-asterisk for 5 s and fail on ERROR-level log lines.
# Asterisk does not exit on bad config — it logs and continues — so we grep
# the boot output. WARNINGs are routine and not gated on; review them manually.
config-test:
    @echo "Booting Asterisk against ./etc-asterisk to validate configs..."
    docker run --rm \
        -v {{etc_dir}}:/etc/asterisk:ro \
        {{full_image}} \
        timeout 5 /usr/sbin/asterisk -fvvv 2>&1 | tee /tmp/asterisk-boot.log || true
    @if grep -qE '] ERROR' /tmp/asterisk-boot.log; then \
        echo; echo "==> Config errors detected (see ERROR lines above)"; exit 1; \
     else \
        echo; echo "==> OK: no ERROR-level lines in boot log"; \
     fi

# Run for local testing
run:
    docker run --rm -it \
        -p 5060:5060/udp -p 5060:5060/tcp -p 5061:5061/tcp \
        -p 10000-10010:10000-10010/udp \
        -v {{etc_dir}}:/etc/asterisk \
        {{full_image}}

# Shortcut to do both
all: build push
