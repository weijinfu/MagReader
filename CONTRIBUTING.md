# Contributing

Thanks for helping improve MagReader.

## Development Principles

- Keep Web and iOS functional independently.
- Preserve local-first behavior; do not require a hosted service for core reading.
- Prefer small, testable changes.
- Update `plan.md` when changing iOS/Web parity, platform behavior, verification status, or next steps.
- Update docs when changing user-visible workflows.

## Setup

```bash
npm install
npm run db:init
npm run dev
```

For iOS, open:

```bash
ios/MagReader/MagReader.xcodeproj
```

## Verification

Before opening a PR, run:

```bash
npm run typecheck
npm test
npm run lint
npm run build
```

For iOS changes, also run the Xcode build/tests when a simulator is available:

```bash
npm run ios:build
npm run ios:test
```

## Pull Requests

Please include:

- What changed.
- Which platform(s) are affected.
- Verification commands and results.
- Screenshots or simulator notes for reader/selection UI changes.

