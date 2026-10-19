# Publishing Haunted Kingdom on Vercel

## Read this first

**Vercel cannot run the Windows `.exe`.** Vercel hosts *websites* — HTML, JS,
CSS and serverless JavaScript. Your game as you play it with `play.bat` is a
native Windows program; there is no way to upload it to Vercel and have it run.

What *does* work: Godot can compile the project to **WebAssembly**, so the whole
game runs inside a browser tab. The result is a folder of static files, and
Vercel serves static files perfectly.

```
Godot project  --export "Web"-->  build/web/index.html + .wasm + .pck + .js
                                        |
                                        +--> Vercel --> https://your-game.vercel.app
```

---

## The one-time setup: export templates

Godot needs the **export templates** for 4.7.2 before it can build a web version.
They are not installed by default.

**Easy way (editor):**
1. Open the project in the Godot editor.
2. Top menu: **Editor → Manage Export Templates**.
3. Click **Download and Install**. (~1.3 GB, all platforms.)

They land in:

```
%APPDATA%\Godot\export_templates\4.7.2.stable\
```

You need the `web_release.zip` / `web_debug.zip` files in there.

---

## Building the browser version

Double-click **`export_web.bat`** in this folder.

It runs three steps:

1. imports every asset,
2. exports the `Web` preset (already configured in `export_presets.cfg`),
3. copies `deploy/vercel.json` next to the output.

Output goes to:

```
build\web\index.html
build\web\index.js
build\web\index.wasm
build\web\index.pck        <- your game + the music
build\web/vercel.json
```

You can re-run it any time you change the game.

---

## Test it locally before publishing

A web build **must be served over HTTP**. Double-clicking `index.html` will
give you a blank page, because browsers block WebAssembly from `file://`.

```
cd build\web
python -m http.server 8000
```

Then open **http://localhost:8000/**.

You should get a black screen with a **click to play** prompt. Browsers refuse
to start audio or lock the mouse until you click — that is normal, and Godot
handles it for you.

---

## Publishing to Vercel

### Option A — command line (fastest)

Install Node.js first if you don't have it, then:

```
cd build\web
npx vercel login          <- one time, opens your browser
npx vercel --prod
```

The first deploy asks a few questions:

| Question | Answer |
|---|---|
| Set up and deploy? | **Y** |
| Which scope? | your own account |
| Link to existing project? | **N** |
| Project name? | `haunted-kingdom` |
| Directory? | `./` |
| Override settings? | **N** |

It prints a URL like `https://haunted-kingdom.vercel.app`. Done.

### Option B — drag and drop

1. Go to <https://vercel.com/new>.
2. Drag the **`build\web`** folder onto the page.
3. Deploy.

### Option C — GitHub (best for updates)

1. Create a repo and put the **contents of `build\web`** at its root.
2. In Vercel: **Add New → Project → Import** that repo.
3. Framework preset: **Other**. Build command: *(empty)*. Output directory: `.`
4. Every `git push` redeploys automatically.

---

## Why `deploy/vercel.json` matters

Godot's web runtime can use **threads** (WebAssembly shared memory). Browsers
only allow that when the page is served with two security headers, otherwise
you get a black screen and a console error about `SharedArrayBuffer`.

`vercel.json` sets them for every file:

```
Cross-Origin-Opener-Policy:   same-origin
Cross-Origin-Embedder-Policy: require-corp
```

It also forces the correct MIME type for `.wasm`, which some hosts get wrong.

Keep `vercel.json` in the same folder as `index.html`.

---

## Expected caveats

| Thing | Reality |
|---|---|
| Download size | ~40–55 MB (engine wasm + your 4.5 MB song) |
| Speed | slower than desktop; WebAssembly, not native |
| Renderer | **Compatibility (WebGL2)** — Forward+ cannot run on the web |
| Visual difference | no volumetric fog / SSAO on web; lighting is simpler |
| Pointer lock | needs one click before the mouse is captured |
| Saves | `user://settings.cfg` goes into browser storage (IndexedDB) |
| Mobile | works on modern phones, but the controls assume keyboard + mouse |

The desktop build is untouched: `project.godot` overrides the renderer **only**
for the `web` feature tag, so `play.bat` still runs Forward+ with full lighting.

---

## Troubleshooting

**"No export template found at the expected path"**
Templates aren't installed. See the one-time setup above.

**Black screen, console says `SharedArrayBuffer`**
`vercel.json` didn't get deployed. Make sure it sits next to `index.html`.

**Black screen, no errors**
You opened `index.html` directly from disk. Serve it over HTTP.

**Music doesn't start**
Click the page once. Browsers block autoplay by design.

**`404: NOT_FOUND`**
The deploy root is wrong — `index.html` must be at the *root* of the deployed
directory, not inside a subfolder.

---

## Licensing note

The soundtrack ("Baanali Jaarida", from *Premada Oorali*) is a commercial
recording. Running it locally is one thing; publishing it on a public URL is
distribution. For a public release you need permission from the rights holders,
or swap `MUSIC_PATH` in `autoload/music.gd` for a track you own or one under a
Creative Commons licence.
