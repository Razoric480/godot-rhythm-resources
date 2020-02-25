# Rhythm Games

Reference by [jusksmit](https://www.reddit.com/user/jusksmit/) from
  [Reddit](https://www.reddit.com/r/gamedev/comments/13y26t/how_do_rhythm_games_stay_in_sync_with_the_music/c78aawd/)

---

Hey there. I've worked on rhythm games before
  ([vid](https://www.youtube.com/watch?v=9pIQrw5mGrU),
  [vid](https://www.youtube.com/watch?v=u-otzm2cymw),
  [vid](https://www.youtube.com/watch?v=s-3SmZaK-yU)).

There are two issues to consider here. The most important one is how to make
  sure you interpret the player's input correctly, so that they feel like
  they're being rewarded accurately, and the slightly less important one is
  making sure that your graphics match the music, so that it looks like the
  notes/actions are happening in sync with the music.

## Video Calibration

We'll start with the second one: making sure your actions/graphics are matching
  the music. Let's assume that our game is similar to DDR or guitar hero: as the
  music plays, notes come falling down the screen towards a "strum bar", and
  when they reach the bar, you're supposed to press a key. Easy, right? You
  could just use a function like this:

```c
renderNoteFallingDownScreen(id:int) {
    note[id].y = strumBar.y - (mySong.position - note[id].strumTime);
}
```

So you write that function, compile, and to your shock and horror, everything is
  wrong. The notes are jittery/stuttery, and when they do finally manage to
  stutter their way down, it looks like they're hitting the bar about half a
  second behind the song, especially during framerate dips. So what gives?

First of all, in almost all environments where you're playing back an audio file
  (or at least the environments I've worked in: AS3, javascript, C#), it's very
  difficult to get a precise playhead position for an audio file that updates at
  a reasonable rate (~60FPS). In a perfect world, if you traced out the
  playhead/position of an audio file every frame, you would see something like
  this:

0, 17, 33, 50, 67, 83, 100, 117, 133...

But in the real world, the results are going to look something like this:

0,0,0,0,83,83,83,133,133,133,133,200,200...

Instead of giving you a smooth, consistent output, the playhead updates in
  steps. What you need to do is interpolate between those steps, which is
  exactly like interpolation in a multiplayer game.

The easiest way to do this is to keep track of the playhead position with your
  own variable, and automatically add time to that variable every frame. There
  are bad ways to do it:

```c
everyFrame() {
    songTime += 1000/60; // 1000ms in a second, 60 frames per second
}
```

And slightly better ways to do it:

```c
songStarted() {
    previousFrameTime = getTimer();
}

everyFrame() {
    songTime += getTimer() - previousFrameTime;
    previousFrameTime = getTimer();
}

// OR:

songStarted() {
    startTime = getTimer();
}

everyFrame() {
    songTime = getTimer() - startTime;
}
```

However, all three of these methods are imperfect. Or, to be more precise, your
  audio playback method is likely to be imperfect. Either way, it means that
  eventually, your little songTime variable is going to get out of sync with the
  actual audio playhead. This is especially likely to happen if you're in an
  environment where the audio is likely to skip, buffer, or crash - like a web
  game or a game that streams its music instead of playing from a file. It's
  also likely to start off with a slight delay because most audio playback
  routines hiccup at the very start of playback - especially if you're using
  MP3 files that have encoding data baked in, if you're reading the audio file
  from a slow hard drive, or if your gamer is using Chrome's built-in
  "pepperflash" plugin, which is a piece of shit.

So in order to take our songTime and keep it consistent with the actual playhead
  position of the audio file, I like to use a basic easing algorithm to apply
  corrections every time I get a fresh playhead position, like this:

```c
songStarted() {
    previousFrameTime = getTimer();
    lastReportedPlayheadPosition = 0;
    mySong.play();
}

everyFrame() {
    songTime += getTimer() - previousFrameTime;
    previousFrameTime = getTimer();
    if(mySong.position != lastReportedPlayheadPosition) {
        songTime = (songTime + mySong.position)/2;
        lastReportedPlayheadPosition = mySong.position;
    }
}
```

This function will automatically take the songTime variable that I'm tracking
  manually and average it with the actual reported playhead position every time
  a new playhead position is reported. I only do it when I've just received a
  fresh report, because if we keep easing it towards the "stepped" valuable in
  between fresh reports, we're gonna get stuttery playback again. Instead, I'll
  continue to advance the songTime manually until I receive another fresh
  report.

But the fun's not quite over yet! You see, all rendering pipelines have delays
  of their own: the time it takes to actually render the scene, plus a small
  delay for the scene to make it to the user's monitor (and if they're playing
  on a TV this delay will be much bigger). On top of the delay it takes for your
  graphics to make it to the monitor, there is also a delay that happens between
  the user hitting a key and the keystroke making it back to your program. In
  most games, this delay is completely negligible, but when you're dealing with
  rhythm games, you need absolutely perfect accuracy, which means you need to
  account for that small round-trip delay.

Unfortunately, every person's monitor and input devices are different, which
  means there is no universal constant we can add to our playhead. Instead, we
  need the user to run a visual delay test, like the one rock band / guitar hero
  uses. They use two tests, and we'll get to the other one later, but the one
  we're talking about right now is this one.

There are lots of ways to do this test. You can flash the screen, or you can
  show a visual indicator like a metronome, and ask the user to tap along with
  the indicator. There should be no audio playing during this test: you are
  trying to calibrate their video lag, not their audio lag. Each time your test
  flashes the screen (or makes the metronome tick), record that time. Then, when
  you receive a keystroke back from the user, you just measure the time again.
  Subtract the time you sent out the visual flash (ping) from the time you
  received the keystroke (pong), and that's your visual latency.

In theory, it's not possible to have a negative visual latency, because visual
  latency = rendering lag + input lag. However, the user might be the kind of
  person who consistently plays their notes a little bit earlier than they think
  they need to. If they are, and if their monitor and input devices are both
  very low-latency, it's not impossible to have a negative visual latency, so
  your system needs to be equipped to deal with that.

Also important: you're going to need to run this test for 15-30 seconds to get
  reliable results. A single round-trip ping test is not going to be reliable:
  there are too many variables that can cause inconsistencies, both in the
  rendering/input process and in the user's ability to keep a consistent beat
  with your test. Each time your test ticks and you calculate the lag for that
  tick, add it to an array, then use the average value of that array to set the
  video latency.

Once you've got the stable measurement of the song's position and a fairly good
  video latency, it's easy to display graphics and animations in sync with the
  music, using a formula like this:

```c
renderNoteFallingDownScreen(id:int) {
    note[id].y = strumBar.y - 
        (songTime - note[id].strumTime) + visualLatencySetting;
}
```

And there you have it. The visual side of things is taken care of! Now we need
  to deal with the music itself.

## Audio Calibration

Just like visual lag, there's a lag between when an audio file is processed and
  when the user actually hears it. Again, there are a ton of variables in this
  equation, including their audio hardware, their reaction time, and even their
  distance from the speakers. And to make things even more fun, this audio lag
  is usually totally different from the video lag, which means we can't just use
  the same adjustment variable for both of them.

Fortunately, we can account for this audio lag exactly like we account for the
  video lag, with a test like this. This particular video is using a method
  where the guitar actually listens and plays the note automatically, but for
  your game, the user is probably going to have to tap a key along to the beat,
  which means we're also taking input lag into account here, too.

Because this could result in double-compensating for input lag, you either need
  to fudge the numbers a tiny bit to compensate, or you need to do the audio
  test first and apply the result before starting the video test. In other
  words, every time you get the 'pong' response during the video test, you
  adjust it based on the results of the audio test.

There are two reasons you want to apply the results of the audio test to the
  video test, rather than vice versa. The first reason is that audio latency is
  much more important than video latency. In rhythm games, your eyes guide you
  to the correct note, but your ears tell you when to play it, so they get top
  priority. Another reason why it's safer to do the audio test before the video
  test is because audio latency is usually much, much lower than video latency,
  which means more of the latency is coming from input delays rather than output
  delays. Say, for instance, that I run the audio test and get an audio latency
  of 25ms. If I had to guess, about 20ms of that is coming from the user's
  reaction time and input lag, not lag between your game and the audio hardware.

This also means that the user is more likely to have a negative audio latency.
  Again, this is not terribly uncommon, especially with inexperienced
  players/musicians who will try to overcompensate and end up playing notes a
  little too fast. It's important to note, though, that a user might get
  uncomfortable and overcompensate during a latency test, but then once
  they get into the game, they start mellowing out and hitting notes at the
  right time - but since they adjusted the latency settings based on early note
  hits, their timing will be off again.

To solve this problem, your audio calibration test needs to be as close to real
  gameplay as you can get. The user needs to feel relaxed and in the groove.
  Listening to a metronome ticking with no background noise is stressful and
  difficult. In between every tick, there's a lot of dead silence, and during
  that silence, a lot of people are going to get antsy and lose track of the
  beat, because very few gamers (and even musicians) are accustomed to following
  a metronome without accompaniment. To see what I mean, listen to this and try
  to tap along to the beat, then skip to about 1:15 in this song and tap along
  to the beat. The second one is way easier, right? I've never understood why
  Rock Band uses a metronome tick instead of a simple song with a consistent
  beat, and I think it's very dumb that they're still doing it after all these
  years.

Anyway, assuming you applied the audio latency to the video test, that means
  there might now be a tiny, insignificant discrepancy between the video and the
  audio, because not 100% of the audio latency comes from user input. These
  discrepancies can come from hardware delays, the user's reaction time
  (although this should be minimal; rhythm games are about anticipation,
  not reaction), and even the time it takes for sound waves to travel from their
  speakers to their ears - roughly 1ms per foot between the speakers and the
  user.

Because we tested for audio latency first, the player should always be able to
  close their eyes and play by ear without any problems, even if the video is a
  little bit off; but for hardcore gamers, it's nice to allow them to fine-tune
  things. For that, I like to have a manual adjustment window where I show a
  etronome or a flash (adjusted by the video latency setting) while music is
  playing, and let the user manually tweak their video latency setting up and
  down 1ms at a time until the metronome tick is perfectly in sync with the
  audio.

## Input

Sorry, I know I'm rambling at this point, and I kind of get the feeling that I
  went way more technical than you were expecting. Just one more thing I wanted
  to mention. In most environments, you will get a much more accurate reading of
  a user's input if you take the input reading inside of a listener, rather than
  checking key states in your main game loop. For example, this:

```c
keyPressedListener() {
    keyDownTime = getTimer();
}
```

...is much more accurate than this:

```c
everyFrame() {
    if(keyIsDown) {
        keyDownTime = getTimer();
    }
}
```

Again, this is probably environment-specific, but in the environments I've
  worked in, event listeners fire near-instantly, compared to frame loops which
  only process at around 60FPS or so.
