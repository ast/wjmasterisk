# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Dockerized Asterisk PBX deployment. There is **no application source code here** — the repo packages Asterisk (currently 23.3.0, built from upstream tarball inside the Dockerfile) plus a set of configuration files in `etc-asterisk/` that are bind-mounted into the container at `/etc/asterisk`.

## Common commands

```bash
just build      # docker build . -t sm6wjm/asterisk:latest
just run        # run the container, bind-mounting ./etc-asterisk into /etc/asterisk
just push       # push to registry
just all        # build + push

docker compose up --build   # alternative: uses persistent named volumes for /var/lib and /var/log
```

Inside the running Asterisk CLI (the `-cvvv` foreground process is the CLI):

```
pjsip set logger on        # show SIP traffic
pjsip show registrations   # current registrations
pjsip show aors / contacts
core show channels
core show codecs
rtp show settings
```

Test SIP clients are documented in `README-pjsip.org` — `pjsua` with extensions 6001/6002/6003 (password = username).

## Architecture and gotchas

- **Build**: `Dockerfile` is multistage. The `builder` stage compiles Asterisk from a tarball pulled from downloads.asterisk.org (`./configure --with-pjproject-bundled --with-jansson-bundled`) and runs `make DESTDIR=/out install`. The `runtime` stage installs only the runtime shared libs (no compilers/headers/static libs) and copies `/out/` over. The version is `ARG ASTERISK_VERSION` (default `23.3.0`); canonical value lives in `justfile` (`asterisk_version`), passed via `--build-arg`. Override per-build with `just build <ver>`. **Note**: downloads.asterisk.org keeps only the latest point release per major; bumping past the current one means the old `wget` URL 404s, so update the version in lockstep with upstream. The tarball in the repo root (`asterisk-23-current.tar.gz`) is **not** built — it's excluded via `.dockerignore`.
- **Trixie runtime libs**: the t64 transition renamed several libs — `libssl3t64`, `libcurl4t64`, `libasound2t64`. If you bump the base image to a different Debian release, those names will likely change.
- **Container user**: runs as `asterisk` (UID/GID 1000). Files in `etc-asterisk/` must be readable by UID 1000; if you add files (especially TLS keys) check ownership before puzzling over permission errors.
- **Image name inconsistency**: `justfile` tags `sm6wjm/asterisk:latest`; `docker-compose.yml` references `sm6wjm.se/asterisk:latest`. They are *not* interchangeable — `just build` won't produce the image compose expects unless you build via `docker compose build`.
- **Ports**: SIP on 5060/udp+tcp, SIP-TLS on 5061/tcp, RTP on 10000–10010/udp. The RTP range in `Dockerfile` EXPOSE, `justfile` run recipe, `docker-compose.yml`, and Asterisk's `rtp.conf` all need to stay in sync. EXPOSE is informational; the published ports come from `docker run`/compose.
- **TLS**: `pjsip.conf` `[transport-tls]` expects `/etc/asterisk/keys/asterisk.pem` and `asterisk.key`. The `etc-asterisk/keys/` directory is bind-mounted along with the rest of `etc-asterisk` (compose) — note `README.org` shows an older invocation that mounts `./keys` separately; the current compose layout has keys *inside* `etc-asterisk/keys`.
- **Dialplan**: `etc-asterisk/extensions.conf` is intentionally minimal — context `internal` with three `Dial(PJSIP/600x)` entries matching the three endpoints in `pjsip.conf`. New extensions need entries in both files.
- **NAT**: `pjsip.conf` `[transport-defaults]` whitelists RFC1918 + CGNAT (100.64.0.0/10, for Tailscale) as `local_net`. Set `external_media_address` / `external_signaling_address` there before exposing to the public internet.

## Editing configs

The `etc-asterisk/` directory **is** the source of truth — it's bind-mounted live, so changes take effect on Asterisk restart (or `module reload` / `pjsip reload` from the CLI) without rebuilding the image. Don't bake configs into the image.
