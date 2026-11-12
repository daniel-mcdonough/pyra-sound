# Lessons

<!-- Full list of tooling, build and harness gotchas. Grep only. Copy the ~10 that come up every session into PROMPT.md
Part B. One `##` per gotcha, with the error text or command in the heading so it can be grepped. -->

## `amixer: Cannot find the given element` for `Headset Stereophone Jack`

The jack controls are `iface=CARD`, not `MIXER`. Use `amixer -c L15 cget iface=CARD,name='Headset Stereophone Jack'`.
