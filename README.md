# Tahoe 5

Tahoe 5 is a browser-based video poker game inspired by the original Turbo Pascal shareware version published in 1992.

## Project Background

This project was based on a Turbo Pascal shareware game I published in 1992. It was made available for DOS, Windows and the Atari Portfolio. Unfortunately, I lost the source code decades ago.

So last summer, I vibe coded a text mode version using Turbo Pascal 4.0 in a DOS Box with some ChatGPT assistance. I wrote most of the code (about 600 lines) by hand. ChatGPT generated an efficient shuffle algorithm as well as the music routines. The latter didn't compile and had to be corrected by hand.

Now with ChatGPT 5.3 and the CodeX app from OpenAI, I created a PRD from the working Turbo Pascal source code. Then I asked it to generate a VS Code project. It created the JavaScript app (around 700 lines) and the related html and css files (another 700 lines.) It compiled and ran first time! I added some graphics for the cards and then added a few features and fixed minor bugs using prompts in CodeX.

I did not write or review any code in this version. It just worked!

## What This Repo Contains

- A playable web video poker app in `/app`
- Product requirements document in `/docs/PRD-video-poker-web.md`
- Version snapshots in `/versions` (`v1.0`, `v1.1`, `v1.2`)

## Features

- Classic 5-card draw video poker loop
- Hold toggles by click/tap and keyboard (`1-5`)
- Keyboard controls for deal/draw (`Enter`), bet (`arrows`), help (`H`), info (`I`), sound (`S`)
- Audio cues for deal, hold, wins, losses, and special win tiers
- Custom card graphics including themed backs and face-card artwork
- Hidden Secret Test Mode (`Z` in result state) for rapid hand evaluation testing

## Run Locally

```bash
cd app
python3 -m http.server 8080
```

Open:

`http://localhost:8080`

## Version Restore

Use snapshots under `/versions` to restore earlier states:

```bash
# Example: restore v1.2
rsync -a --delete /Users/urlocker/Downloads/Vibe1/versions/v1.2/app/ /Users/urlocker/Downloads/Vibe1/app/
```
