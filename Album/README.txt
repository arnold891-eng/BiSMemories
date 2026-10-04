BiS Memories - your album
=========================

The addon takes the pictures and writes down what each one was. This folder turns them into an
album you can click through.


HOW TO USE IT
-------------

1. Double-click  BiSMemories-Album.html  in this folder. It opens in your browser.

2. Click "Choose your Screenshots folder" and point it at:

       C:\Program Files (x86)\World of Warcraft\_classic_beta_\Screenshots

   Swap _classic_beta_ for whichever you play - _classic_era_, _classic_, _retail_ - and if you
   installed WoW somewhere else, it is the Screenshots folder sitting beside the WTF folder.

   Your browser will ask whether to let the page read that folder. Say yes. That prompt is the
   browser protecting you; the page is not asking for anything else.

   You can also just DRAG the Screenshots folder onto the page, which saves the browsing.

3. That is the album. Click a picture to see it full size, arrow keys to move between them,
   Escape to come back.


FINDING ONE PICTURE
-------------------

Search the box at the top for a zone, a boss, an item, a level - anything the addon wrote down,
and the filename besides. Beside it is a row of counts: "12 boss", "12 death", "18 zone". Click
one to see only those, click it again to stop.

With a search or a filter on, the arrow keys move between the pictures you can SEE, not all of
them - so filtering to boss kills and holding right takes you through the boss kills.


FOR THE CAPTIONS
----------------

The pictures alone give you dates. The addon knows more - the zone, your level, why the picture
was taken - and it keeps that in its saved file.

THAT FILE IS NOT IN YOUR ADDONS FOLDER. It is in WTF, which is where WoW keeps everything it
remembers about you. Click "Add the addon's notes" and pick:

    C:\Program Files (x86)\World of Warcraft\_classic_beta_\WTF\Account\<ACCOUNT>\SavedVariables\BiSMemories.lua

<ACCOUNT> is a number and a hash - something like 213614#1 - not your email address. Open
WTF\Account and there is usually only one folder in there; go into that one.

There is a second copy further in, under your realm and character:

    ...\WTF\Account\<ACCOUNT>\<Realm>\<Character>\SavedVariables\BiSMemories.lua

Either works. The first is simpler because it holds every character you play.

Now every picture the addon took carries its story. Pictures you took yourself still show, just
without a caption.

You only have to do this once. The page keeps the notes in your browser, so the next time you
open it the captions are already there and it asks for the Screenshots folder alone. It tells you
what it kept and when, and there is a "forget them" beside that line. Load the file again
whenever you want the newer notes - pictures taken since the last time you loaded it have none.

The FOLDERS cannot be remembered, only the notes. When you pick a folder, the page is handed the
files and the folder's name, never where it sits on your disk - so it has nothing to go back to.
That is the same rule as the one below: a web page may not wander your drive.


THINGS WORTH KNOWING
--------------------

* Nothing is uploaded. Nothing is installed. There is no server and no internet connection
  involved - the page reads the files off your disk and shows them. You can unplug the network
  and it works exactly the same.

* It cannot go looking for the folder by itself. A web page is not allowed to wander around your
  hard drive, which is a good thing, so you point it at the Screenshots folder once per visit.
  The captions are the part it can keep.

* Dates come from the filename, not from the file. The client names screenshots
  WoWScrnShot_MMDDYY_HHMMSS, and that is the only honest timestamp: a file's "modified" date is
  when it was last copied, so a folder moved to a new drive would otherwise claim every picture
  was taken on the same afternoon.

* Chrome, Edge and Firefox can all pick a folder. Safari is patchy about it; if the folder button
  does nothing there, use another browser.

* Notes are written when you log out or /reload, never the moment the picture is taken. A shot
  from the last few minutes of play has no caption yet - reload the game and it will.


/memories journal in game shows the same notes as a list, without the pictures - an addon cannot
read your Screenshots folder or draw a .jpg, which is exactly why this page exists.
