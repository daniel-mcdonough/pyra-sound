# Docs index

One line per file. Read the doc for the area you're changing; don't read them all.

| File | Covers | Tier |
|---|---|---|
| `audio-stack.md` | Card L15, mixer controls, AESS vs direct PulseAudio layouts, volume wheel, jack detection | 3: read when touching audio |
| `BACKLOG.md` | Cold NEXT items, same IDs | 4: grep only |
| `LESSONS.md` | Full list of tooling and harness gotchas | 4: grep only |

## How to write a subsystem doc

- One topic per `##` section. Put the words someone would grep for in the heading: function names, file names,
  IDs.
- Current state at the top of each section, history (how we got here, approaches that failed) below it.
- One home per fact. Other docs link to it instead of copying it.
- If a fact is only useful when editing files in one directory, put it in that directory's `CLAUDE.md` instead. It
  loads automatically when those files are touched.
