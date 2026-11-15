# Lessons

<!-- Full list of tooling, build and harness gotchas. Grep only. Copy the ~10 that come up every session into PROMPT.md
Part B. One `##` per gotcha, with the error text or command in the heading so it can be grepped. -->

## `amixer: Cannot find the given element` for `Headset Stereophone Jack`

The jack controls are `iface=CARD`, not `MIXER`. Use `amixer -c L15 cget iface=CARD,name='Headset Stereophone Jack'`.

## `[Errno 21] Is a directory: 'src/__pycache__'` from `python3 -m py_compile src/*`

py_compile writes `src/__pycache__/`, and the next run's glob picks it up. Run
`python3 -m py_compile src/* && rm -rf src/__pycache__`.

## ssh session dies with exit 255 after `pkill -f <pattern>`

`pkill -f` over `ssh pyra-release '...'` also matches the remote shell, whose command line contains the pattern.
Use `pkill -x pyra-sound` (process name), not `-f`.

## Running a GUI program on the Pyra over ssh

The MATE session is on `:0`. `export DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus`, then
`setsid -f pyra-sound >/tmp/pyra-sound.log 2>&1`. Without the bus address, `Gtk.Application` can't register its name.

## `dpkg-deb: command not found` on the build host

The host is Arch. Inspect the .deb in the container:
`docker run --rm -v "$PWD/dist:/d:ro" debian:trixie dpkg-deb -c /d/pyra-sound_0.1_all.deb`. The locally cached
`debian:trixie` image is linux/arm/v7 (emulated); `build-deb.sh` works with it anyway.

## `ssh pyra-release '... setsid -f ...'` never returns

A child started with `setsid -f` that keeps the ssh session's stdout open holds the ssh command until the tool
timeout. Redirecting only inside `sh -c "pyra-sound >/dev/null 2>&1"` is not enough: the `sh` itself keeps the fds
(S13). Redirect the whole thing, `setsid -f pyra-sound >/dev/null 2>&1 </dev/null`, give ssh `</dev/null`, or run
the ssh in the background.

## Killing a test `alsactl monitor` also kills pyra-sound's

`pkill -f 'alsactl monitor hw:L15'` matches pyra-sound's own monitor too. pyra-sound restarts it after 5 s, but
kill test monitors by PID or by their parent shell instead.

## `./build-deb.sh`: "failed to connect to the docker API"

The Docker daemon isn't started on the host by default, and starting it needs the user's sudo password: ask them to
run `! sudo systemctl start docker`. For a script-only change, `scp` + `sudo install -m755` over
`/usr/bin/pyra-sound` on the Pyra tests the same code.

## Re-pushing a release tag: `gh release create` fails, "release already exists"

`.github/workflows/release.yml` creates the release; it doesn't replace one. To move a published tag (e.g. after a
history rewrite), delete the GitHub release first (web UI; `gh` isn't logged in on the host), then
`git push origin :refs/tags/vX` and push the tag again. `git filter-repo` drops `origin`; add it back before pushing.
Workflow runs and releases can be read without auth while the repo is public (a private repo gives 404, S13): `curl -s https://api.github.com/repos/<owner>/pyra-sound/actions/runs` (owner from `git remote -v`).

Waiting on a build: `until ! pgrep -f build-deb.sh; do sleep 3; done` matches its own `bash -c` command line and
never ends (S15). Run the build itself with `run_in_background` and wait for its notification.
