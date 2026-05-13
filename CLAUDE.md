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

docker compose up --build   # alternative: uses compose.yaml (network_mode: host, persistent volumes, healthcheck, SIGINT stop)
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

Test SIP clients are documented in `README.org` under "Test clients (pjsua / pjproject)" — `pjsua` with any of the configured extensions (password = username by default; "; change me" comments mark the placeholders).

## Architecture and gotchas

- **Build**: `Dockerfile` is multistage. The `builder` stage compiles Asterisk from a tarball pulled from downloads.asterisk.org (`./configure --with-pjproject-bundled --with-jansson-bundled`) and runs `make DESTDIR=/out install`. The `runtime` stage installs only the runtime shared libs (no compilers/headers/static libs) and copies `/out/` over. The version is `ARG ASTERISK_VERSION` (default `23.3.0`); canonical value lives in `justfile` (`asterisk_version`), passed via `--build-arg`. Override per-build with `just build <ver>`. **Note**: downloads.asterisk.org keeps only the latest point release per major; bumping past the current one means the old `wget` URL 404s, so update the version in lockstep with upstream. The tarball in the repo root (`asterisk-23-current.tar.gz`) is **not** built — it's excluded via `.dockerignore`.
- **Trixie runtime libs**: the t64 transition renamed several libs — `libssl3t64`, `libcurl4t64`, `libasound2t64`. If you bump the base image to a different Debian release, those names will likely change.
- **Container user**: runs as `asterisk` (UID/GID 1000). Files in `etc-asterisk/` must be readable by UID 1000; if you add files (especially TLS keys) check ownership before puzzling over permission errors.
- **Networking**: Both `just run` and `compose.yaml` use **host networking** (`--network host` / `network_mode: host`). Asterisk binds directly on the host's interfaces — no `-p`/`ports:` mapping. Reason: SIP SDP embeds the host's IP, and bridge-NAT rewrites those to the bridge subnet, which remote clients can't route back to. Don't reintroduce bridge networking without also setting `external_media_address` in `pjsip.conf`.
- **Ports**: SIP on 5060/udp+tcp, SIP-TLS on 5061/tcp, RTP on 10000–10010/udp. The RTP range in Asterisk's `rtp.conf` and the `Dockerfile` `EXPOSE` line should stay aligned. EXPOSE is informational only; with host networking, ports come from Asterisk's own `bind=` and `rtpstart/rtpend` settings.
- **Stop signal**: Asterisk shuts down cleanly on SIGINT, not SIGTERM. `compose.yaml` sets `stop_signal: SIGINT`; manual `docker run` smoke tests should use `docker kill -s INT`. See the Testing section.
- **TLS**: `pjsip.conf` `[transport-tls]` expects `/etc/asterisk/keys/asterisk.pem` and `asterisk.key`. The `etc-asterisk/keys/` directory is bind-mounted along with the rest of `etc-asterisk` (compose) — note `README.org` shows an older invocation that mounts `./keys` separately; the current compose layout has keys *inside* `etc-asterisk/keys`.
- **Dialplan**: `etc-asterisk/extensions.conf` uses the pattern `_6XXX` to dial any 4-digit extension starting with 6, plus feature codes `*97` (voicemail) and `*43` (echo test). Adding a new phone only requires a new endpoint block in `pjsip.conf` (using a template) — the dialplan needs no changes as long as the number stays in the 6XXX range.
- **PJSIP templates**: `pjsip.conf` uses three endpoint templates — `[softphone]`, `[ata]`, `[mobile]` — covering LAN softphones (opus/g722/ulaw), POTS adapters (G.711 only, UDP), and remote SIP clients (TLS+SRTP on 5061). Each phone is ~6 lines copy-paste once you pick a template. Numbering convention: 6001–6009 softphones, 6010–6019 ATAs, 6020–6029 mobile.
- **NAT**: `pjsip.conf` `[transport-defaults]` whitelists RFC1918 + CGNAT (100.64.0.0/10, for Tailscale) as `local_net`. Set `external_media_address` / `external_signaling_address` there before exposing to the public internet.

## Editing configs

The `etc-asterisk/` directory **is** the source of truth — it's bind-mounted live, so changes take effect on Asterisk restart (or `module reload` / `pjsip reload` from the CLI) without rebuilding the image. Don't bake configs into the image.

## Testing

**Always pass `--rm` when spinning up containers for testing.** Smoke tests that use `docker run -d` without `--rm` leave the container behind on exit/kill, and a long session can accumulate many of them (each holding port reservations and bind mounts). Pattern for a quick boot-and-inspect:

```bash
cid=$(docker run -d --rm -v "$(pwd)/etc-asterisk:/etc/asterisk:ro" sm6wjm/asterisk:latest)
until docker exec "$cid" /usr/sbin/asterisk -rx "core waitfullybooted" 2>/dev/null | grep -q "fully booted"; do sleep 0.5; done
# ...inspect via docker exec / docker logs...
docker kill -s INT "$cid" >/dev/null   # SIGINT, not SIGTERM — Asterisk shuts down cleanly on INT
```

Note: don't try `docker run timeout --signal=INT N /usr/sbin/asterisk` — `timeout` becomes PID 1 in the container and docker's signal handling makes the SIGINT to its child unreliable; the container often hangs. The detached + `docker kill -s INT` pattern above is what actually works.
