# Development

## Web Development

Work from the `web/` directory.

Install dependencies:

```bash
cd web
npm install
```

Initialize the local database:

```bash
npm run db:init
```

Run the app:

```bash
npm run dev
```

Run verification:

```bash
npm run typecheck
npm test
npm run lint
npm run build
```

## iOS Development

Open:

```bash
open ios/MagReader.xcodeproj
```

Use the `MagReader` scheme. Build and test with Xcode Product > Build and Product > Test.

## Documentation Rules

Update these files when relevant:

- `README.md`: public overview and quick start.
- `docs/architecture.md`: architecture or data-flow changes.
- `docs/platforms.md`: platform support changes.
- `docs/ios-web-feature-comparison.md`: Web/iOS parity changes.
- Keep implementation notes local unless they are useful public documentation.
