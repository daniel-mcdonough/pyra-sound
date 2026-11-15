# pyra-sound

A sound icon for MATE's Notification Area on the DragonBox Pyra. It takes the
place of MATE's own sound icon: left click mutes, right click switches between
the speakers and the headphones.

## The problem

The Pyra's headphone jack can't report an unplug, so nothing switches the
sound back to the speakers when you pull the headphones out, and MATE's sound
icon has no quick way to do it by hand either. This icon puts the output one
right click away.

## Requirements

- A DragonBox Pyra running the Debian trixie image with the MATE desktop
- An **AESS kernel** (`5.6.19-m4*`, PulseAudio sink `aess`). On a kernel with
  the direct McPDM audio path, pyra-sound prints `unsupported` and exits
  without an icon.
- For the volume wheel on the headphones: a `pyra_volumed` that drives them
  (see [The volume wheel](#the-volume-wheel))

Dependencies (`python3-gi`, the GTK 3 introspection bindings, `pactl`,
`alsa-utils`) are pulled in by apt.

## Installing

Download `pyra-sound_<version>_all.deb` from the Releases page. It is
architecture-independent, so there is only one file per release.

Install it with apt rather than `dpkg -i`, so the dependencies come along:

    sudo apt install ./pyra-sound_<version>_all.deb

The `./` matters; without it apt looks for a package by that name in the
archive and fails.

Then log out and back in. The icon starts with the session, and MATE's sound
icon no longer does.

To upgrade, install the newer `.deb` the same way. To remove it:

    sudo apt remove pyra-sound

## Using it

| Input | Does |
| --- | --- |
| Left click | Mute / unmute |
| Right click | Open a small window: *Speakers* or *Headphones*, and a bar with the volume (or a headphone volume slider, see below). Click outside it or press Escape to close. |
| Volume wheel | Volume of both outputs, through `pyra_volumed` |

The **icon** is MATE's own volume icon while the speakers play, a headphones
picture while the headphones play, and the muted icon on either output when
muted.

The **tooltip** names the output and the volume, for example
`Speakers: 62%` or `Headphones: muted`. The percentage is where the wheel
is: 0% at the bottom stop, 100% at the top, the same on the speakers and the
headphones (with a daemon that doesn't drive the headphones, the headphone
slider's value while they play). PulseAudio's volume normally stays at 100%;
if something else (a volume control, a media key) moves it, the tooltip adds
it, as in `Speakers: 62% (PulseAudio 40%)`.

The **bar** in the right-click window shows the same volume as the
tooltip and follows the wheel while the window is open. It is read only: the
wheel's daemon owns that volume.

Changes made elsewhere (MATE's sound preferences, `pactl`, the wheel) show up
in the icon, the tooltip and the bar within a moment. pyra-sound does no work while
nothing changes.

## The volume wheel

The wheel is read by a root daemon, `pyra_volumed`, not by pyra-sound. There
are two daemons by that name:

- **dragonbox-pyra's calibrated `pyra_volumed`**, and pyra-hacks' from
  `0.38+pyra2` on, set the speaker and the headphone amplifier together on
  every turn, so the wheel works on whichever output plays.
- **pyra-hacks' packaged `pyra_volumed` up to 0.38** sets only the speakers.
  With it, or with no daemon running, the right-click window shows a
  headphone volume slider in place of the bar while the headphones play.

The slider sets the headphone amplifier directly. With the calibrated daemon
a slider value would only hold until the next turn of the wheel, which is why
the slider only shows when the wheel doesn't reach the headphones. pyra-sound
checks which daemon runs each time the window opens, and reads the wheel's
speaker range (`range lo hi` in `/etc/pyra_volumed.conf`, for pyra-hacks'
daemon) then too.

The headphone amplifier has no silent step; its lowest setting is quiet, not
off. Use left click to mute.

## MATE's sound icon

The package hides MATE's sound icon (`mate-volume-control-status-icon`) with
an autostart entry in `/etc/xdg/pyra/autostart`, which the Pyra's session
reads before `/etc/xdg`. Nothing in your home directory or in MATE's package
is changed.

- **Removing pyra-sound** brings MATE's icon back at the next login. The
  running icon stays until you log out.
- **To keep MATE's icon** for one user while pyra-sound is installed, copy its
  entry into your own autostart directory:

      mkdir -p ~/.config/autostart
      cp /etc/xdg/autostart/mate-volume-control-status-icon.desktop ~/.config/autostart/

  Then both icons show. To hide pyra-sound's for that user instead, put a copy
  of `/etc/xdg/autostart/pyra-sound.desktop` there with `Hidden=true` added.

`apt remove` leaves `/etc/xdg/autostart/pyra-sound.desktop` behind, as it
does with every configuration file. It is inert without the program
(`TryExec`) and goes with `sudo apt purge pyra-sound`.

## How it works

pyra-sound talks to PulseAudio as the logged-in user, through `pactl`: mute is
the `aess` sink's mute, and the output is its port, `pyra-speaker` or
`pyra-headphones`. A `pactl subscribe` child reports outside changes. The
amplifier volumes for the tooltip are read from the ALSA card `L15` with
`amixer`, and `alsactl monitor` reports their changes. No root, no udev rules,
no setuid helpers.

It never writes the speaker amplifier's volume (`Handsfree Playback Volume`):
`pyra_volumed` owns it and would overwrite it.

Only one copy runs per session; a second start exits.

## Troubleshooting

**No icon after logging in.** Run `pyra-sound` in a terminal. If it prints
`unsupported`, the running kernel uses the direct McPDM audio path; boot an
AESS kernel (`uname -r` shows `5.6.19-m4…`). Its other messages also land in
`~/.xsession-errors`.

**The wheel doesn't change the headphone volume.** The packaged
`pyra_volumed` up to 0.38 (or none) is running. Use the slider in the
right-click window, or install a daemon that drives the headphones.

**MATE's icon is still there.** It goes away from the next login on. If it
still shows after a new login, check that `/etc/xdg/pyra` comes first in
`echo $XDG_CONFIG_DIRS` (set by the image's `pyra-config-desktop`) and that
`~/.config/autostart` holds no copy of MATE's entry.

## Building from source

    ./build-deb.sh

builds `dist/pyra-sound_<version>_all.deb` in a Debian trixie container, so it
needs Docker. On a Debian machine, `dpkg-buildpackage -b -uc -us` also works.

## License

GPL-2.0-or-later. See `COPYING`.
