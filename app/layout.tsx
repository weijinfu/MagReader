import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "MagReader",
  description: "A local-first English article reader for language learners."
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <style dangerouslySetInnerHTML={{ __html: mobileCacheBypassCss }} />
        {children}
      </body>
    </html>
  );
}

const mobileCacheBypassCss = `
@media (max-width: 820px) {
  html, body {
    overflow-x: hidden !important;
  }

  body {
    padding-bottom: calc(76px + env(safe-area-inset-bottom)) !important;
  }

  .app-shell,
  .app-shell.nav-collapsed {
    display: grid !important;
    grid-template-columns: 1fr !important;
  }

  .sidebar,
  .sidebar.collapsed {
    position: fixed !important;
    top: auto !important;
    right: 0 !important;
    bottom: 0 !important;
    left: 0 !important;
    z-index: 40 !important;
    height: auto !important;
    min-height: 0 !important;
    display: block !important;
    overflow: visible !important;
    border-right: 0 !important;
    border-top: 1px solid var(--line) !important;
    border-bottom: 0 !important;
    padding: 8px 10px calc(8px + env(safe-area-inset-bottom)) !important;
    background: var(--panel) !important;
  }

  .brand,
  .sidebar-section,
  .sidebar.collapsed .collapse-button {
    display: none !important;
  }

  .main {
    display: flex !important;
    min-width: 0 !important;
  }

  .nav-list {
    display: grid !important;
    grid-template-columns: repeat(6, minmax(0, 1fr)) !important;
    gap: 4px !important;
    min-width: 0 !important;
    margin: 0 !important;
  }

  .nav-button,
  .sidebar.collapsed .nav-button {
    min-height: 52px !important;
    padding: 6px 2px !important;
    flex-direction: column !important;
    justify-content: center !important;
    gap: 3px !important;
    border-radius: 8px !important;
  }

  .nav-icon,
  .sidebar.collapsed .nav-icon {
    display: block !important;
    width: 19px !important;
    height: 19px !important;
    flex: 0 0 auto !important;
  }

  .nav-abbrev {
    display: none !important;
  }

  .nav-label,
  .sidebar.collapsed .nav-label {
    max-width: 100% !important;
    overflow: hidden !important;
    flex: 0 1 auto !important;
    font-size: 11px !important;
    line-height: 1.15 !important;
    text-overflow: ellipsis !important;
    white-space: nowrap !important;
  }

  .nav-label-full {
    display: none !important;
  }

  .nav-label-short,
  .sidebar.collapsed .nav-label-short {
    display: block !important;
  }

  .nav-count,
  .sidebar.collapsed .nav-count {
    display: block !important;
    margin-left: 0 !important;
    font-size: 10px !important;
    line-height: 1 !important;
  }

  .topbar,
  .content-grid,
  .content-grid.list-collapsed {
    grid-template-columns: 1fr !important;
  }

  .topbar {
    gap: 10px !important;
    padding: 10px !important;
  }

  .toolbar {
    display: grid !important;
    grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
    gap: 6px !important;
    justify-content: stretch !important;
  }

  .content-grid,
  .content-grid.list-collapsed {
    gap: 12px !important;
    padding: 10px !important;
  }

  .article-list-panel {
    order: 2 !important;
  }

  .reader-wrap {
    order: 1 !important;
    min-width: 0 !important;
  }

  .reader {
    width: 100% !important;
    max-width: 100% !important;
    padding: 16px !important;
    box-shadow: none !important;
  }

  .reader h1 {
    font-size: 28px !important;
    line-height: 1.12 !important;
  }

  .learning-panel {
    display: none !important;
  }

  .mobile-learning-sheet {
    position: fixed !important;
    right: 10px !important;
    bottom: calc(72px + env(safe-area-inset-bottom)) !important;
    left: 10px !important;
    z-index: 36 !important;
    display: grid !important;
    max-height: 55vh !important;
    overflow: auto !important;
    border: 1px solid var(--line) !important;
    border-radius: 8px !important;
    background: var(--panel) !important;
    padding: 8px 12px 12px !important;
  }

  .mobile-sheet-active .selection-toolbar {
    display: none !important;
  }

  .mobile-sheet-actions {
    display: grid !important;
    grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
    gap: 8px !important;
  }

  .mobile-selected-text {
    display: -webkit-box !important;
    overflow: hidden !important;
    -webkit-box-orient: vertical !important;
    -webkit-line-clamp: 3 !important;
  }

  .mobile-selected-text.expanded {
    display: block !important;
  }
}
`;
