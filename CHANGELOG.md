# BiSMemories

## 0.2.0

- **The album, in game.** `/memories journal` opens what happened: newest first, the wheel to walk
  back through it, Escape to close. A memory taken while it is open appears in front of you.

  **No pictures, and that will not change.** An addon cannot list a folder - the only reason this
  one knows a screenshot exists is that it took it and wrote the name down from the clock - and a
  `.jpg` outside `Interface\` cannot be drawn on a frame at all. That is on every client, not just
  this one, and it is why the HTML album exists: a browser can open those files and the game
  cannot. The journal keeps each filename beside its entry so a picture on disk still matches the
  night it came from.

- **`/memories heard`** - what the camera was told, and what never arrived. An album with one
  picture has two explanations that look the same from outside: nothing happened, or the event
  never came. This prints the counts since login, the verdict on the last few, and every event it
  registered for that has not fired at all. It answered that question in one reload.

- On the Forever beta the log starts empty at every login, because that client hands back no saved
  variables to any addon. The journal says so in words rather than looking broken.

## 0.1.0

Takes a screenshot when something worth remembering happens - and writes down what it was, so a
year later the picture still means something.

- **What sets it off:** levelling up, a boss dying (a wipe is not a memory), loot of epic quality or
  better, an achievement, your own death, winning a duel, walking into a zone you have never seen,
  and going exalted. Each one is a switch: `/memories off boss`.
- **One candid a week.** An unposed picture at a random moment while you play - never on login,
  which would just be the same loading screen fifty-two times a year.
- **The note is the point.** Every shot records the reason, the zone, your level, who was in the
  group, and the filename the client wrote, so a picture in Screenshots\ can be matched to its
  moment. `/memories` reads the last ten back; `/memories all` reads the lot.
- **A click of its own**, because the client only plays its camera sound for the PrintScreen key -
  silence would be indistinguishable from "it did not work". `/memories sound` turns it off.
- Runs on WoW Forever and on 2.5.6 from one TOC. Nothing it reads is hidden by Forever's lockdown.

## 0.0.1

- Created from the BiS house skeleton (`_bisdev/new-addon.sh`): shared BiS channel, palette, tests, CI and
  release from GitHub already wired.
