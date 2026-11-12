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
| Sinks | one sink `aess`, ports `pyra-speaker` (prio 100), `pyra-headphones` (prio 90) | 4-channel `alsa_output.hw_CARD_L15_DEV_0` plus remap sinks `speakers` (rear pair, default) and `headphones` (front pair) |
| Switch output | `pactl set-sink-port aess pyra-headphones` / `pyra-speaker`; the port's mixer path flips the codec routes | change default sink and move streams; both amps stay routed, split by channel |
| PA card | `alsa_card.L15` | none (bare `module-alsa-sink`) |

- PA volume is software volume on both paths. Changing a PA sink volume does not touch the ALSA volume controls.
- On the direct path, muting one remap sink leaves the other playing. Mute the master sink instead.
- On AESS, `module-switch-on-port-available` is loaded, and the headphones port has `[Jack Headset Stereophone]
  required-any`. Untested: whether PA refuses or reverts a manual switch to an "unavailable" port.

## Volume wheel: pyra_volumed

- Tapered pot on IIO `palmas-gpadc`, channel `voltage2`. Not an input device.
- `pyra_volumed` (system service, pyra-hacks) polls it and writes only `Handsfree Playback Volume` on `hw:CARD=L15`.
  It sets no routes and never touches `Headset Playback Volume`.
- It overwrites manual writes to the Handsfree volume, even without the wheel moving (seen 2026-10-20 upstream).
- So for this project the Handsfree volume is the wheel's position, read-only, and the headphone volume has to be
  derived from it: watch Handsfree, write `Headset Playback Volume`. The two ranges differ (30 vs 16 steps,
  -52..+6 vs -30..0 dB), so a mapping has to be chosen.

## Headphone jack detection

- ALSA jack kctls `Headset Stereophone Jack` (numid 37), `Headset Mic Jack` (36). They are `iface=CARD`, so
  `amixer cget name=...` alone doesn't find them: use `amixer -c L15 cget iface=CARD,name='Headset Stereophone Jack'`
  (verified 2026-11-12); input device `Letux Cortex 15 Headset Jack`
  reporting `SW_HEADPHONE_INSERT`.
- Stock kernels: always reads "inserted" (the TWL6040's detect is stuck; the real detector, a TS3A227E, never
  probes). Fixed only in `5.6.19-m4-kbdled` (patches 0037-0039 in `../dragonbox-pyra/experiments/jack-detect/`).
- Even with the fix, **unplug is not detected while the headset amp is powered**. That is a hardware limit, so
  there's no automatic switch back to the speakers. This is why pyra-sound switches by hand on right click.

## MATE's sound icon: mate-volume-control-status-icon

- From `mate-media`, pulled in by `mate-desktop-environment` (dependency of `pyra-meta-mate`). Started by
  `/etc/xdg/autostart/mate-volume-control-status-icon.desktop` and shown in the panel's Notification Area
  (`NotificationAreaAppletFactory::NotificationArea`, right-stuck at position 3 in the image's
  `pyra-backlight.layout`). It is an ordinary tray icon; nothing about it is special.
- `pyra-sound` replaces it: our autostart entry adds a tray icon, and a per-user override with `Hidden=true` stops
  MATE's from starting (NEXT 1.4).
