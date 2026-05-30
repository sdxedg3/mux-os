# Mux-OS MVP

> Forked from [DreaM117er/mux-os](https://github.com/DreaM117er/mux-os) — stripped to core: **Android App Launcher via Termux**.

Short commands to launch any app on your Android phone from Termux. No bloat, no flavor text.

## Quick Start

```bash
git clone https://github.com/sdxedg3/mux-os.git
cd mux-os
echo 'export PATH="$HOME/mux-os:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Usage

```bash
# Enter command mode (required once per session)
mux login

# Launch apps
mux chrome
mux tg           # Telegram
mux gemini
mux map
mux yt           # YouTube

# Search (if app supports it)
mux chrome "weather today"
mux yt "music"
mux mapgo "Orchard Road"

# Lock when done
mux logout
mux status       # Check current state
mux              # Show all available commands
```

## Commands

| Alias   | App              | Search |
|---------|------------------|--------|
| chrome  | Chrome           | ✅ Google |
| edge    | Edge             | ✅ Bing |
| yt      | YouTube          | ✅ Search |
| gemini  | Google Gemini    | |
| grok    | Grok (xAI)       | |
| gmail   | Gmail            | |
| gdrive  | Google Drive     | |
| meet    | Google Meet      | |
| map     | Google Maps      | |
| mapto   | Map → search     | ✅ Geo |
| mapway  | Map → directions | ✅ Route |
| mapgo   | Map → navigate   | ✅ Nav |
| tg      | Telegram         | |
| x       | X / Twitter      | |
| github  | GitHub           | |
| phone   | Phone dialer     | |
| play    | Play Store       | ✅ Search |
| ...     | (see `mux`)      | |

## Adding Your Own Apps

Edit `app.csv`:

```
# command,type,pkg,target,search_engine
myapp,NA,com.example.app,.MainActivity,
```

- **NA** = direct launch (no args)
- **NB** = can take a search query (requires `search_engine` URL)

## How It Works

```
mux chrome → am start -n com.android.chrome/...Main
mux yt "cat" → am start -a VIEW -d "https://youtube.com/results?search_query=cat"
```

State machine prevents accidental launches:

```
$ mux chrome
✗ Commands locked. Run 'mux login' first.
```

## License

MIT — original by [@DreaM117er](https://github.com/DreaM117er).
