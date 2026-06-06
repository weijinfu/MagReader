# Security Policy

MagReader is local-first software. It stores user data locally and talks directly to RSS, translation, and dictionary services.

## Reporting Issues

If you find a security issue, please avoid filing a public exploit with reproduction data that could harm users. Open a private report through the repository host when available, or contact the maintainers through the project issue tracker with a minimal non-sensitive description.

## Scope

Security-sensitive areas include:

- RSS/HTML ingestion and sanitization.
- Local SQLite persistence.
- Export endpoints.
- Translation/dictionary network requests.
- Web reader selection and rendered article HTML.
- iOS `WKWebView` rendering and JavaScript bridge.

## Supported Versions

The current `main` branch is the only supported development line until tagged releases begin.

