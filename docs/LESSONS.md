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
