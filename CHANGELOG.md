# BiSMemories

## 0.3.1

- **Loot pictures are yours again.** `CHAT_MSG_LOOT` carries the whole raid's loot, and the only
  test was the item's quality - so in a 25-man every epic anybody won was a photograph, every few
  seconds, all night. Now it takes **your** loot at the quality you set, plus **anyone's
  legendary**, because an orange dropping is the room's memory and not just the winner's.

  Whose line it is comes from the client's own strings, so it works the same in any language.

  If it was driving you mad before this update: `/memories off loot` stops it at once, no reload.

## 0.3.0

- **Make your own album, from your own screenshots.** The addon folder now carries
  `Album\BiSMemories-Album.html`. Double-click it, point it at your Screenshots folder, and it
  becomes an album you click through - full size on click, arrow keys to move, grouped by day.

  Hand it the addon's saved file as well and every picture it took carries its story: the zone,
  your level, and why it was worth a picture.

  **Nothing is uploaded and nothing is installed.** There is no server and no internet connection
  involved - your browser reads the files off your own disk. Unplug the network and it works the
  same. It asks you to pick the folder because a web page is not allowed to go wandering through
  your drive, which is a good thing.

  `Album\README.txt` has the same in longer words, including where the folders usually live.

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
