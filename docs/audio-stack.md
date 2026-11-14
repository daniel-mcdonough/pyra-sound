# Pyra audio stack, as pyra-sound sees it

Source: `../dragonbox-pyra/docs/audio.md` (the upstream reference), `../pyra-kernel/sound/soc/codecs/twl6040.c`,
`../pyra-hacks/pyra_volumed.c`, `../dragonbox-pyra/device/pulse/`. Facts here were collected from those files on
2026-11-12. Ones checked on the device (`ssh pyra-release`) say so.

## The test unit (verified 2026-11-12)

- `pyra-release`: kernel `5.6.19-m4-kbdled`, AESS path, Debian trixie. L15 happened to be card 4.
- PA: one sink `aess` (`module-alsa-card.c`). Ports `pyra-speaker` (priority 10000, availability unknown) and
  `pyra-headphones` (priority 9000, "not available" with nothing plugged in). Active port `pyra-speaker`.
- Readings at the time: Handsfree 21,21; Headset 13,13.
- `pyra_volumed` runs as `/usr/local/bin/pyra_volumed` (not from a package; the unit has a drop-in in
  `/etc/systemd/system/pyra_volumed.service.d`).
- `mate-volume-control-status-icon` is running.
- Installed: `alsa-utils`, `pulseaudio-utils`. Not installed but in the archive: `python3-alsaaudio` 0.10.0,
  `python3-pulsectl` 24.12.0.

## Card L15 and the TWL6040 controls

- One codec card, ALSA id `L15` (from DT model "Letux Cortex 15"). Its number changes between boots.
- `Headset Playback Volume`: stereo, 0..15, -30..0 dB, 2 dB steps. Headphones.
- `Handsfree Playback Volume`: stereo, 0..29, -52..+6 dB, 2 dB steps. Speakers.
- Route muxes (enumerated, use `amixer -c L15 cset name='...'`, not `sset`):
  `Headset Left/Right Playback` = {Off, HS DAC, Line-In amp};
  `Handsfree Left/Right Playback` = {Off, HF DAC, Line-In amp}.
- At boot `pyra-audio-route-apply` (udev rule from the image) sets all four routes to their DAC, so both amps are on.
- No UCM for L15, and none should be added (see upstream audio.md, "Why a profile set and not UCM").

## Two kernel paths, two PulseAudio layouts

This project supports **AESS only** (decided 2026-11-12). The direct column is kept so a direct kernel can be
recognised and reported as unsupported.

Which one is running depends on the kernel:

    grep -q 'MultiMedia1 LP' /proc/asound/pcm && echo AESS || echo direct

| | AESS (`5.6.19-m4`, `-m4-kbdled`) | Direct McPDM (`-fix`, `-freq`, `-pyradef`) |
|---|---|---|
| PA script | `/etc/pulse/pyra-aess.pa` | `/etc/pulse/pyra.pa` (pyra-config-pulseaudio) |
| Sinks | one sink `aess`, ports `pyra-speaker` (prio 10000), `pyra-headphones` (prio 9000) | 4-channel `alsa_output.hw_CARD_L15_DEV_0` plus remap sinks `speakers` (rear pair, default) and `headphones` (front pair) |
| Switch output | `pactl set-sink-port aess pyra-headphones` / `pyra-speaker`; the port's mixer path flips the codec routes | change default sink and move streams; both amps stay routed, split by channel |
| PA card | `alsa_card.L15` | none (bare `module-alsa-sink`) |

- PA volume is software volume on both paths. Changing a PA sink volume does not touch the ALSA volume controls.
- Mute on AESS: `pactl set-sink-mute aess toggle`; read back with `pactl get-sink-mute aess`, which prints
  `Mute: yes` / `Mute: no` (PA protocol 35 on the test unit). Used by pyra-sound's left click, verified
  2026-11-12 by clicking the tray icon.
- On the direct path, muting one remap sink leaves the other playing. Mute the master sink instead.
- On AESS, `module-switch-on-port-available` is loaded, and the headphones port has `[Jack Headset Stereophone]
  required-any`. A manual switch to it is still accepted while it reads "not available" with nothing plugged in:
  `pactl set-sink-port aess pyra-headphones` exits 0 and `Active Port` stays `pyra-headphones` (checked after 3 s);
  the module doesn't revert it (verified 2026-11-13). pyra-sound's right-click window relies on this.
- The port paths route exclusively (verified 2026-11-13): `pyra-headphones` sets `Headset Left Playback` = HS DAC
  and `Handsfree Left Playback` = Off; `pyra-speaker` the reverse. So after the first switch, the boot state "both
  amps on" (from `pyra-audio-route-apply`) is gone, and only one output plays.

## Volume wheel: pyra_volumed

- Tapered pot on IIO `palmas-gpadc`, channel `voltage2`. Not an input device.
- Two daemons exist, both called `pyra_volumed`, both a root system service that polls the pot:
  - pyra-hacks' packaged `/usr/bin/pyra_volumed` up to 0.38 writes only `Handsfree Playback Volume`. The
    headphones get no wheel. From the user's local `0.38+pyra2` on (`../pyra-hacks`, commit `eb1d488`) it writes
    `Headset` too, over `hsrange lo hi` in `/etc/pyra_volumed.conf` (default 0..15). The test unit runs
    `0.38+pyra3` since 2026-11-14 evening; the calibrated `/usr/local/bin` one is gone from it.
  - dragonbox-pyra's calibrated one (`device/pyra-volumed/`, built to `/usr/local/bin/pyra_volumed` by
    `pyra-volumed-run`, commit `177efeb` there) writes `Handsfree` and `Headset Playback Volume` from the same
    wheel travel on every turn, whichever port plays (each amp sits behind its own route). Headset covers all 16
    steps (0 at the bottom stop). This is the one on the test unit (since 2026-11-14).
- Either overwrites manual writes to the Handsfree volume, even without the wheel moving (seen 2026-10-20
  upstream). So Handsfree is read-only for us. A Headset write holds until the next wheel turn.
- Since NEXT 1.8 (2026-11-14) pyra-sound never copies the wheel to the headphones; the daemon does.
- Telling the two apart (`wheel_drives_headset()` in `src/pyra-sound`): find the process by `/proc/PID/comm` =
  `pyra_volumed`, take the binary from `argv[0]` in `/proc/PID/cmdline` (`/proc/PID/exe` is root's and gives
  EACCES to the session user), and look for `Headset Playback Volume` (calibrated build, full control name) or
  `\0Headset\0` (pyra-hacks, which uses the simple mixer API, element names `Handsfree` / `Headset`, so the
  full name isn't in its binary). Verified 2026-11-14: the calibrated binary has the full name, pyra-hacks
  `0.38+pyra3` has `\0Headset\0`, stock pyra-hacks 0.38 has neither (only `\0Handsfree\0`); `pyra-volumed-run` execs the absolute path, so argv[0]
  is `/usr/local/bin/pyra_volumed`. No daemon, or one without the string: the popup shows its headphone volume
  slider. Checked on every popup open, since the daemon can be rebuilt or restarted under a running session.
- Change detection for the tooltip: `/usr/sbin/alsactl monitor hw:L15` (not on a user's PATH) prints one line per
  control change, e.g. `node hw:L15, #30 (2,0,0,Handsfree Playback Volume,0) VALUE`, and flushes per line into a
  pipe. A write of the same value produces no event, so the daemon's rewrites of an unchanged position don't wake
  pyra-sound (verified 2026-11-13). `watch_mixer()` re-reads Handsfree / Headset on their events.
- The popup shows the playing output's amp volume as a `Gtk.LevelBar` (read only, NEXT 2.5), fed by the same
  reads as the tooltip. On the headphones with a daemon that doesn't drive them, the slider replaces it. The
  LevelBar's default `low`/`high`/`full` offsets are removed (they colour a quiet setting as a warning).

### Wheel to headphones mapping (history, before NEXT 1.8)

- 2026-11-13 to 2026-11-14 pyra-sound itself copied the wheel: on each Handsfree event, with the
  `pyra-headphones` port active, it wrote `Headset = round(handsfree * 15 / 29)` (linear step map, chosen over a
  dB match that would leave a third of the travel dead). HF never reads 1..5 on the unit (`STEP_LO 6` in the
  calibrated daemon), so HS 1..3 were unreachable, and each step cost three subprocesses. That is why it moved
  into the daemon, which maps its own wheel travel onto all 16 Headset steps.
- The TWL6040's Headset volume has no mute step (HS 0 = -30 dB); use left click (PA mute) for silence.

## Following PulseAudio: pactl subscribe

- `pactl subscribe` prints one line per server event and flushes each line into a pipe; events arrive about 10 ms
  after the change (verified on the unit 2026-11-13). pyra-sound runs it as a long-lived child (`watch_pulse()`,
  restarted after 5 s if it ends) and does one `pactl list sinks` 100 ms after the first `sink` / `server` event
  of a burst (`queue_refresh()`).
- Mute, volume and port changes on `aess` all come as `Event 'change' on sink #0`. Setting a volume to the value
  it already has gives no sink event.
- Every pactl call adds `new` / `change` / `remove` events `on client #N`, so filtering to `sink` / `server`
  keeps pyra-sound's own reads from triggering more reads.
- Idle cost: none. With both monitors running, no pyra-sound thread woke up in 30 s (`voluntary_ctxt_switches`
  unchanged, 2026-11-13).

## Child lifetime: setpriv --pdeathsig (NEXT 2.3)

- Both watchers start through `watcher()`: `setpriv --pdeathsig TERM <argv>` (util-linux, Essential on trixie),
  so the kernel SIGTERMs them when pyra-sound dies, however it dies. setpriv execs, so `ps` shows plain `pactl` /
  `alsactl` with pyra-sound as parent.
- Why `do_shutdown()` isn't enough: at logout the X connection drops and GDK's IO-error handler calls `exit()`,
  so neither `do_shutdown()` nor the signal handlers run (reproduced 2026-11-14 with `xkill -id` on pyra-sound's
  window). SIGKILL is the same. SIGTERM/SIGINT/SIGHUP did clean up.
- Orphans differ: an orphaned `alsactl monitor` dies of SIGPIPE at the next mixer event; `pactl subscribe`
  ignores SIGPIPE (signal 13 set in `SigIgn` of `/proc/PID/status`) and lives forever, keeping its login session's scope
  and the logind session in `closing`.
- Verified on the unit 2026-11-14 with the fix: xkill, `pkill -KILL`, `pkill` and a real logout/login leave no
  `pactl subscribe` / `alsactl monitor` behind.
- Not ours: on the unit, old x11 sessions also stay `closing` because each holds a leftover `dbp-desktopd`
  (Pyra desktop daemon), with or without pyra-sound.

## Headphone jack detection

- ALSA jack kctls `Headset Stereophone Jack` (numid 37), `Headset Mic Jack` (36). They are `iface=CARD`, so
  `amixer cget name=...` alone doesn't find them: use `amixer -c L15 cget iface=CARD,name='Headset Stereophone Jack'`
  (verified 2026-11-12); input device `Letux Cortex 15 Headset Jack`
  reporting `SW_HEADPHONE_INSERT`.
- Stock kernels: always reads "inserted" (the TWL6040's detect is stuck; the real detector, a TS3A227E, never
  probes). Fixed only in `5.6.19-m4-kbdled` (patches 0037-0039 in `../dragonbox-pyra/experiments/jack-detect/`).
- Even with the fix, **unplug is not detected while the headset amp is powered** (a hardware limit). With nothing
  playing, the amp is off and unplug is seen at once.
- On m4-kbdled, PA already follows the jack (verified 2026-11-14, NEXT 2.1). The speaker port also
  goes "not available" while the jack reads in. Plug-in: jack kctl `on`, `module-switch-on-port-available` moves
  `aess` to `pyra-headphones` and the routes flip, playing or not. Unplug while idle: PA switches back to
  `pyra-speaker`. Unplug while playing: missed, `aess` stays on headphones and the speakers read "not available".
  A manual `pactl set-sink-port aess pyra-speaker` is still accepted (rc 0, routes flip). It powers the headset
  amp down, so the detector then catches the unplug: jack `off`, headphones "not available", no stuck state.
  pyra-sound therefore has no jack code; it only follows the sink events. Right click remains the way back.

## MATE's sound icon: mate-volume-control-status-icon

- From `mate-media`, pulled in by `mate-desktop-environment` (dependency of `pyra-meta-mate`). Started by
  `/etc/xdg/autostart/mate-volume-control-status-icon.desktop` and shown in the panel's Notification Area
  (`NotificationAreaAppletFactory::NotificationArea`, right-stuck at position 3 in the image's
  `pyra-backlight.layout`). It is an ordinary tray icon; nothing about it is special.
- Its autostart file belongs to `mate-media-common` (a conffile) and has no `AutostartCondition`, so no gsettings
  key turns it off (checked 2026-11-13).
- The session's `XDG_CONFIG_DIRS` is `/etc/xdg/pyra:/etc/xdg`, set by `pyra-config-desktop`'s
  `/etc/X11/Xsession.d/65pyra_xdg-config` (seen in mate-panel's environment 2026-11-13). A same-named file in
  `/etc/xdg/pyra/autostart` masks MATE's. On the image `pyra-config-desktop` comes in through `pyra-meta-desktop-base`
  and `pyra-config-all`; pyra-sound only `Recommends:` it.
- `pyra-sound` replaces it: our autostart entry adds a tray icon, and the package's mask (`Hidden=true`, shipped as
  a symlink so `apt remove` deletes it) stops MATE's from starting (NEXT 1.4). Verified on the unit 2026-11-13:
  mate-session honours the mask (`Hidden=true` in `/etc/xdg/pyra/autostart`); after a fresh login only pyra-sound
  runs, and after `apt remove` (symlink and the then-empty `/etc/xdg/pyra/autostart` gone) MATE's icon is back at
  the next login. The running MATE icon stays until logout.
- Per user, a copy of `/etc/xdg/autostart/pyra-sound.desktop` with `Hidden=true` appended in `~/.config/autostart`
  stops pyra-sound at the next login while MATE's stays masked: no sound icon at all, nothing in `~/.xsession-errors`.
  Removing the copy brings pyra-sound back (verified on the unit 2026-11-14, NEXT 1.10; README's instructions).
- Our own `/etc/xdg/autostart/pyra-sound.desktop` is a conffile and survives `apt remove` (state `rc`). Without
  `TryExec=pyra-sound`, mate-session logs `Could not launch application 'pyra-sound.desktop'` to
  `~/.xsession-errors` at every login after removal; the entry carries `TryExec` for that.
- Its icons are the full-colour theme names `audio-volume-muted` / `-low` / `-medium` / `-high` (from the
  binary's strings; theme `mate`), not the `-symbolic` ones, chosen by PA sink volume in thirds of 100%. pyra-sound
  uses the same names and rule (`icon_for()`); the user confirmed both look identical 2026-11-12. On AESS the sink
  volume normally sits at 100% (the wheel moves ALSA, not PA), so it shows "high" unless muted.
- MATE's icons don't show the output. pyra-sound shows the theme's `audio-headphones` (in theme `mate`) while the
  headphones port is active and not muted; muted is `audio-volume-muted` on either output (user's choice
  2026-11-13).
- pyra-sound's tooltip is `Speakers: N%` / `Headphones: N%` / `<output>: muted`. N is the amp volume as a share of
  its steps: Handsfree/29 (the wheel) on the speakers, Headset/15 (the wheel through the calibrated daemon, or the popup slider,
  same % as the slider) on the headphones. The PA volume is left out and assumed to be 100%; when it isn't, the tooltip
  adds `(PulseAudio N%)` (user 2026-11-13: the wheel's volume is what counts).
- No scroll on the icon (user's decision 2026-11-14, NEXT 2.2). Scroll can't move the wheel's volume
  (`pyra_volumed` overwrites Handsfree), so it could only step the `aess` PA software volume, a second volume in
  series with the amp: "wheel at max but still quiet", accidental turn-downs from the nubs' scroll mode over the tray,
  and digital attenuation where the amp would do better. The wheel is the volume control; a PA volume off 100% shows
  in the tooltip and is reset in MATE's sound preferences. Unlike MATE's icon, which scrolls the PA volume.
