# Development

## Web Development

Install dependencies:

```bash
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
open ios/MagReader/MagReader.xcodeproj
```

Use the `MagReader` scheme.

Command-line build:

```bash
npm run ios:build
```

Command-line tests:

```bash
npm run ios:test
```

The `ios:test` script expects an iOS Simulator named `iPhone 17`. If your simulator differs, run `xcodebuild` directly with your destination.

## Documentation Rules

Update these files when relevant:

- `README.md`: public overview and quick start.
- `docs/architecture.md`: architecture or data-flow changes.
- `docs/platforms.md`: platform support changes.
- `docs/ios-web-feature-comparison.md`: Web/iOS parity changes.
- `plan.md`: progress notes, verification status, risks, and next steps.

