# Platforms

## Web

Status: active.

Use the Web app when you want a local desktop/browser workflow with export support.

Commands:

```bash
npm run dev
npm run verify
```

Data:

```text
data/magreader.db
```

Override:

```bash
MAGREADER_DB=/absolute/path/magreader.db npm run dev
```

## iOS

Status: active.

Use the iOS app when you want a native phone/tablet workflow without running the Web app.

Open:

```bash
open ios/MagReader/MagReader.xcodeproj
```

Build:

```bash
npm run ios:build
```

Data:

```text
iOS app sandbox SQLite
```

## Planned Or Possible Platforms

These are not implemented:

- macOS native app.
- Android app.
- Desktop packaged Web app.
- Cloud sync service.

Add a platform only when there is a clear user workflow that Web/iOS cannot cover well.

