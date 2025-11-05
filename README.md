# README #

### What is this repository for? ###

Subler is an Mac OS X app created to mux and tag mp4 files. The main features includes:

* Creation of tx3g subtitles tracks, compatible with all Apple's devices (iPod, AppleTV, iPhone, QuickTime?).
* Mux video, audio, chapters, subtitles and closed captions tracks from mov, mp4 and mkv.
* Raw formats: H.264 Elementary streams (.h264, .264), AAC (.aac), AC3 (.ac3), Scenarist (.scc), VobSub? (.idx).
* metadata editing and TMDb, TVDB and iTunes Store support.

### Build and run

Clone the repository and include all submodules
```
git clone --recurse-submodules https://github.com/SublerApp/Subler.git
```
If you already cloned without submodules and need to add the submodules manually, `cd` into the `./Subler` directory and clone the dependency submodules with 
```
git submodule update --init --recursive
```
Open `Subler.xcodeproj` in Xcode.

Build and run the project by selecting the 'Subler' scheme (`Product` -> `Scheme` -> `Subler`) and clicking the 'Run' button in Xcode’s toolbar.

### Command-line interface

The repository also ships with a lightweight CLI wrapper around MP42Foundation.

1. In Xcode choose the `SublerCLI` scheme and build (`Product` -> `Build`).
2. The compiled tool lives at `DerivedData/.../Build/Products/<configuration>/SublerCLI` alongside a `Frameworks` directory containing the bundled `MP42Foundation.framework`.
3. Run it directly from that location or copy both the executable and `Frameworks` directory to another folder.

Basic usage:

```
SublerCLI input.mkv \
  --output output.m4v \
  --force-hvc1 \
  --overwrite
```

The CLI remuxes without transcoding MP4-safe video, preserves every audio and subtitle track (converting non-MP4-safe formats like FLAC/Vorbis or PGS to AAC/tx3g automatically), and accepts additional switches such as `--audio-bitrate`, `--mixdown`, `--optimize`, and `--no-progress`. Run `SublerCLI --help` to see the full option list.


