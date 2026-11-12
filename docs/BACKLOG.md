# Backlog

<!-- Cold NEXT items. Grep only, never read whole. IDs are the same as they were in NEXT.md. Move an item back into
NEXT.md before working on it. Entries may be stale: check PROGRESS.md before trusting a "not done" claim here. -->

## 2. Later

### 2.1 Switch to headphones on plug-in (m4-kbdled only)

On `5.6.19-m4-kbdled` the jack reports plug-in correctly (TS3A227E patches). PA's port availability may already
do this on AESS; check before writing anything. Unplug can't be detected (hardware), so never auto-switch back.

### 2.2 Scroll on the icon

Scrolling can't move the wheel's volume (`pyra_volumed` overwrites Handsfree). It could change the PA sink volume
instead, but then there are two volumes in series. Decide whether that's worth it.

### 2.3 Coexistence with MATE's own sound status icon

`mate-volume-control-status-icon` also shows mute and volume. Decide whether the README tells users to turn it off.
