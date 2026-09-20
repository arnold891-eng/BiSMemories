BiS Memories - your album
=========================

The addon takes the pictures and writes down what each one was. This folder turns them into an
album you can click through.


HOW TO USE IT
-------------

1. Double-click  BiSMemories-Album.html  in this folder. It opens in your browser.

2. Click "Choose your Screenshots folder" and point it at:

       World of Warcraft\_classic_beta_\Screenshots

   (or _classic_era_, _classic_, _retail_ - whichever version you play)

   Your browser will ask whether to let the page read that folder. Say yes. That prompt is the
   browser protecting you; the page is not asking for anything else.

3. That is the album. Click a picture to see it full size, arrow keys to move between them,
   Escape to come back.


FOR THE CAPTIONS
----------------

The pictures alone give you dates. The addon knows more - the zone, your level, why the picture
was taken - and it keeps that in its saved file. Click "Add the addon's notes" and pick:

    World of Warcraft\<version>\WTF\Account\<YOUR ACCOUNT>\SavedVariables\BiSMemories.lua

Now every picture the addon took carries its story. Pictures you took yourself still show, just
without a caption.


THINGS WORTH KNOWING
--------------------

* Nothing is uploaded. Nothing is installed. There is no server and no internet connection
  involved - the page reads the files off your disk and shows them. You can unplug the network
  and it works exactly the same.

* It cannot go looking for the folder by itself. A web page is not allowed to wander around your
  hard drive, which is a good thing, so you point it at the folder once per visit.

* Dates come from the filename, not from the file. The client names screenshots
  WoWScrnShot_MMDDYY_HHMMSS, and that is the only honest timestamp: a file's "modified" date is
  when it was last copied, so a folder moved to a new drive would otherwise claim every picture
  was taken on the same afternoon.

* Chrome, Edge and Firefox can all pick a folder. Safari is patchy about it; if the folder button
  does nothing there, use another browser.

* On the WoW Forever beta the addon's saved file is emptied by the client at every login - that
  is a client fault affecting every addon, not this one. Your PICTURES are unaffected; only the
  captions for older sessions are missing.


/memories journal in game shows the same notes as a list, without the pictures - an addon cannot
read your Screenshots folder or draw a .jpg, which is exactly why this page exists.
