# MagReader Web

The Web version is a local-first Next.js app for desktop and browser reading. It stores data in a local SQLite database and talks directly to RSS, translation, and dictionary services.

## Features

- RSS/Atom feed management and refresh.
- Article list grouped by Feed with collapsible sections.
- Reader typography controls, dark mode, and article-list collapse.
- Two-step word/sentence highlight and translate flow.
- Fast Google/MyMemory translation with optional dictionary meanings.
- Saved Words, Saved Sentences, Review, CSV/JSON export.

## Requirements

- Node.js 20+
- npm
- Network access for RSS refresh, translation, and dictionary lookup

## Setup

```bash
npm install
npm run db:init
npm run dev
```

Default local URL:

```text
http://127.0.0.1:3000
```

## Local Data

Default database path:

```text
web/data/magreader.db
```

Use another database file:

```bash
MAGREADER_DB=/absolute/path/magreader.db npm run dev
```

If you previously used the old root-level database, point `MAGREADER_DB` to that file explicitly.

## Translation

User-visible providers:

- Google public endpoint
- MyMemory

Single-word dictionary details are loaded on demand from `dictionaryapi.dev` through the `Show More Meanings` action.

## Commands

```bash
npm run dev
npm run build
npm run start
npm run lint
npm run typecheck
npm test
npm run verify
npm run db:init
```

## Verification

Before changing Web behavior, run:

```bash
npm run verify
```

The production build may print the existing non-fatal Next.js ESLint plugin notice because this project uses a custom flat ESLint config.

