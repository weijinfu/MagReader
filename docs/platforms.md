# Platforms

## Web

Status: active.

Use the Web app when you want a local desktop/browser workflow with export support.

See `web/README.md` for setup and verification commands.

Data:

```text
web/data/magreader.db
```

Override:

```bash
cd web
MAGREADER_DB=/absolute/path/magreader.db npm run dev
```

## iOS

Status: active.

Use the iOS app when you want a native phone/tablet workflow without running the Web app.

Open:

```bash
open ios/MagReader.xcodeproj
```

Build with Xcode Product > Build. See `ios/README.md`.

Data:

```text
iOS app sandbox SQLite
```

## macOS

Status: active.

Use the macOS app when you want a native desktop workflow with local data, native speech, keyboard commands, and CSV/JSON export.

Open:

```bash
open macos/MagReaderMac.xcodeproj
```

Build with Xcode Product > Build. See `macos/README.md`.

Data:

```text
~/Library/Application Support/MagReaderMac/magreader-macos.db
```

## Planned Or Possible Platforms

These are not implemented:

- Android app.
- Desktop packaged Web app.
- Cloud sync service.

Add a platform only when there is a clear user workflow that Web/iOS/macOS cannot cover well.
