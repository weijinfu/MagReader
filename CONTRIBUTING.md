# Contributing

Thanks for helping improve MagReader.

## Development Principles

- Keep Web and iOS functional independently.
- Preserve local-first behavior; do not require a hosted service for core reading.
- Prefer small, testable changes.
- Update docs when changing user-visible workflows.

## Setup

For Web:

```bash
cd web
npm install
npm run db:init
npm run dev
```

For iOS, open:

```bash
ios/MagReader.xcodeproj
```

## Verification

Before opening a PR, run:

```bash
cd web
npm run typecheck
npm test
npm run lint
npm run build
```

For iOS changes, use Xcode Product > Build and Product > Test.

## Pull Requests

Please include:

- What changed.
- Which platform(s) are affected.
- Verification commands and results.
- Screenshots for reader/selection UI changes.
