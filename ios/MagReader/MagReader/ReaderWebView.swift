import SwiftUI
import WebKit

struct ReaderWebView: UIViewRepresentable {
    var article: Article
    var settings: ReaderSettings
    var onSelection: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "selection")
        controller.addUserScript(WKUserScript(source: selectionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.scrollView.backgroundColor = .clear
        context.coordinator.webView = view
        view.loadHTMLString(renderedHTML, baseURL: nil)
        context.coordinator.currentHTML = renderedHTML
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSelection = onSelection
        let html = renderedHTML
        if context.coordinator.currentHTML != html {
            context.coordinator.currentHTML = html
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, UIGestureRecognizerDelegate {
        var onSelection: (String) -> Void
        var currentHTML = ""
        weak var webView: WKWebView?

        init(onSelection: @escaping (String) -> Void) {
            self.onSelection = onSelection
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "selection", let text = message.body as? String else { return }
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                onSelection(clean)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    private var renderedHTML: String {
        let background = readerBackgroundColor
        let foreground = settings.isDark ? "#f3efe6" : "#1d1b18"
        let secondary = settings.isDark ? "#b8b2a7" : "#706a60"
        let accent = settings.isDark ? "#68d4ba" : "#0f766e"
        let body = sanitizeHTML(article.contentHtml)
        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <style>
            :root { color-scheme: \(settings.isDark ? "dark" : "light"); }
            * { box-sizing: border-box; }
            body {
              margin: 0;
              padding: 24px 20px 48px;
              background: \(background);
              color: \(foreground);
              font-family: \(settings.fontFamily), Georgia, serif;
              font-size: \(settings.fontSize)px;
              line-height: \(settings.lineHeight);
              -webkit-text-size-adjust: 100%;
              -webkit-user-select: none;
              -webkit-touch-callout: none;
              user-select: none;
            }
            main { max-width: 760px; margin: 0 auto; }
            h1 {
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
              font-size: 30px;
              line-height: 1.12;
              margin: 0 0 8px;
              letter-spacing: 0;
            }
            .meta {
              color: \(secondary);
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              font-size: 14px;
              margin-bottom: 28px;
            }
            p, li, blockquote, figcaption { margin: 0 0 \(settings.paragraphGap)em; }
            a { color: \(accent); }
            img, video, iframe, figure { max-width: 100%; height: auto; }
            blockquote {
              border-left: 3px solid \(accent);
              padding-left: 16px;
              color: \(secondary);
            }
            .magreader-selected-text {
              background: rgba(20, 184, 166, .30);
              border-radius: 5px;
              box-shadow: 0 0 0 2px rgba(20, 184, 166, .16);
            }
            .magreader-selected-block {
              background: rgba(20, 184, 166, .12);
              border-radius: 10px;
              box-shadow: 0 0 0 8px rgba(20, 184, 166, .08);
            }
            ::selection { background: rgba(20, 184, 166, .35); }
          </style>
        </head>
        <body>
          <main>
            <h1>\(escapeHTML(article.title))</h1>
            <div class="meta">\(escapeHTML(article.feedTitle ?? "Local feed")) · \(escapeHTML(article.difficulty))</div>
            \(body)
          </main>
        </body>
        </html>
        """
    }

    private var readerBackgroundColor: String {
        if settings.isDark {
            return "#111315"
        }
        switch settings.readerBackground {
        case "white":
            return "#ffffff"
        case "warm":
            return "#fff7ed"
        case "green":
            return "#f0f7ef"
        case "gray":
            return "#f4f4f5"
        default:
            return "#fbfaf7"
        }
    }

    private var selectionScript: String {
        """
        (function() {
          if (window.__magReaderSelectionBridgeInstalled) { return; }
          window.__magReaderSelectionBridgeInstalled = true;

          let nativeSelectionTimer = null;
          let suppressNativeSelection = false;
          let lastPostedText = "";
          let lastPostedAt = 0;
          let lastNativeSelectionText = "";
          let pendingText = "";
          let pendingKind = "";
          let suppressClickUntil = 0;
          let longPressTimer = null;
          let longPressStart = null;

          const selectableBlockSelector = "p, li, blockquote, figcaption, h1, h2, h3, h4";

          function cleanText(text) {
            return String(text || "").replace(/\\s+/g, " ").trim();
          }

          function postSelection(text) {
            const clean = cleanText(text);
            if (!clean) { return; }
            const now = Date.now();
            if (clean === lastPostedText && now - lastPostedAt < 800) { return; }
            lastPostedText = clean;
            lastPostedAt = now;
            window.webkit.messageHandlers.selection.postMessage(clean);
          }

          function restoreNativeSelection(range) {
            const selection = window.getSelection && window.getSelection();
            if (!selection) { return; }
            suppressNativeSelection = true;
            selection.removeAllRanges();
            selection.addRange(range);
            lastNativeSelectionText = cleanText(range.toString());
            setTimeout(function() { suppressNativeSelection = false; }, 300);
          }

          function clearCustomHighlights() {
            document.querySelectorAll(".magreader-selected-text").forEach(function(mark) {
              const parent = mark.parentNode;
              if (!parent) { return; }
              while (mark.firstChild) {
                parent.insertBefore(mark.firstChild, mark);
              }
              parent.removeChild(mark);
              parent.normalize();
            });
            document.querySelectorAll(".magreader-selected-block").forEach(function(block) {
              block.classList.remove("magreader-selected-block");
            });
          }

          function setPendingSelection(text, kind) {
            pendingText = cleanText(text);
            pendingKind = kind || "";
          }

          function clearPendingSelection() {
            pendingText = "";
            pendingKind = "";
            clearCustomHighlights();
          }

          function commitPendingSelection() {
            if (!pendingText) { return false; }
            postSelection(pendingText);
            return true;
          }

          function highlightRange(range) {
            clearCustomHighlights();
            const copy = range.cloneRange();
            try {
              const mark = document.createElement("mark");
              mark.className = "magreader-selected-text";
              copy.surroundContents(mark);
            } catch (error) {
              const mark = document.createElement("mark");
              mark.className = "magreader-selected-text";
              mark.appendChild(copy.extractContents());
              copy.insertNode(mark);
            }
          }

          function elementFromRangeContainer(container) {
            if (!container) { return null; }
            return container.nodeType === Node.ELEMENT_NODE ? container : container.parentElement;
          }

          function selectableBlockForRange(range) {
            const element = range ? elementFromRangeContainer(range.startContainer) : null;
            return element ? element.closest(selectableBlockSelector) : null;
          }

          function pointRange(x, y) {
            if (document.caretRangeFromPoint) {
              return document.caretRangeFromPoint(x, y);
            }
            if (document.caretPositionFromPoint) {
              const position = document.caretPositionFromPoint(x, y);
              if (!position) { return null; }
              const range = document.createRange();
              range.setStart(position.offsetNode, position.offset);
              range.collapse(true);
              return range;
            }
            return null;
          }

          function textNodeAtRange(range) {
            if (!range) { return null; }
            if (range.startContainer && range.startContainer.nodeType === Node.TEXT_NODE) {
              return { node: range.startContainer, offset: range.startOffset };
            }
            const walker = document.createTreeWalker(range.startContainer, NodeFilter.SHOW_TEXT);
            const node = walker.nextNode();
            return node ? { node: node, offset: 0 } : null;
          }

          function wordRangeAtPoint(x, y) {
            const range = pointRange(x, y);
            const hit = textNodeAtRange(range);
            if (!hit || !hit.node || !hit.node.nodeValue) { return null; }
            const text = hit.node.nodeValue;
            let offset = Math.max(0, Math.min(hit.offset, text.length));

            const isWordChar = function(character) { return /[A-Za-z'-]/.test(character); };
            if (offset >= text.length && text.length > 0) { offset = text.length - 1; }
            if (!isWordChar(text.charAt(offset)) && offset > 0 && isWordChar(text.charAt(offset - 1))) {
              offset -= 1;
            }
            if (!isWordChar(text.charAt(offset))) { return null; }

            let start = offset;
            let end = offset + 1;
            while (start > 0 && isWordChar(text.charAt(start - 1))) { start -= 1; }
            while (end < text.length && isWordChar(text.charAt(end))) { end += 1; }

            while (start < end && /['-]/.test(text.charAt(start))) { start += 1; }
            while (end > start && /['-]/.test(text.charAt(end - 1))) { end -= 1; }
            if (end <= start) { return null; }

            const selected = text.slice(start, end);
            if (!/^[A-Za-z][A-Za-z'-]*$/.test(selected)) { return null; }

            const wordRange = document.createRange();
            wordRange.setStart(hit.node, start);
            wordRange.setEnd(hit.node, end);
            return wordRange;
          }

          function sentenceRangeAtPoint(x, y) {
            const range = pointRange(x, y);
            const block = selectableBlockForRange(range);
            const hit = textNodeAtRange(range);
            if (!block || !hit || !hit.node || !hit.node.nodeValue) { return null; }

            const walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT, {
              acceptNode: function(node) {
                return cleanText(node.nodeValue) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
              }
            });
            const nodes = [];
            let fullText = "";
            let hitOffsetInBlock = -1;
            let node = walker.nextNode();
            while (node) {
              const start = fullText.length;
              const value = node.nodeValue || "";
              nodes.push({ node: node, start: start, end: start + value.length });
              if (node === hit.node) {
                hitOffsetInBlock = start + Math.max(0, Math.min(hit.offset, value.length));
              }
              fullText += value;
              node = walker.nextNode();
            }
            if (hitOffsetInBlock < 0 || !cleanText(fullText)) { return null; }

            const boundary = /[.!?。！？]/;
            let start = hitOffsetInBlock;
            while (start > 0) {
              if (boundary.test(fullText.charAt(start - 1))) { break; }
              start -= 1;
            }
            let end = hitOffsetInBlock;
            while (end < fullText.length) {
              if (boundary.test(fullText.charAt(end))) {
                end += 1;
                break;
              }
              end += 1;
            }

            while (start < end && /\\s/.test(fullText.charAt(start))) { start += 1; }
            while (end > start && /\\s/.test(fullText.charAt(end - 1))) { end -= 1; }
            if (end <= start) { return null; }

            const selected = cleanText(fullText.slice(start, end));
            if (selected.length < 8 || !/\\s/.test(selected)) { return null; }

            const startPart = nodes.find(function(part) { return start >= part.start && start <= part.end; });
            const endPart = nodes.find(function(part) { return end >= part.start && end <= part.end; });
            if (!startPart || !endPart) { return null; }

            const sentenceRange = document.createRange();
            sentenceRange.setStart(startPart.node, start - startPart.start);
            sentenceRange.setEnd(endPart.node, end - endPart.start);
            return sentenceRange;
          }

          function selectableBlockFromPoint(x, y) {
            const element = document.elementFromPoint(x, y);
            if (!element || element.closest("a, button, input, textarea, select")) { return null; }
            return element.closest(selectableBlockSelector);
          }

          function previewWordAtPoint(x, y) {
            const range = wordRangeAtPoint(x, y);
            if (!range) { return false; }
            const selected = cleanText(range.toString());
            highlightRange(range);
            setPendingSelection(selected, "word");
            return selected;
          }

          function previewSentenceAtPoint(x, y) {
            const range = sentenceRangeAtPoint(x, y);
            if (!range) { return false; }
            const selected = cleanText(range.toString());
            clearCustomHighlights();
            highlightRange(range);
            setPendingSelection(selected, "sentence");
            return selected;
          }

          function previewNativeSelection(selection, text) {
            if (!selection || selection.rangeCount === 0) { return false; }
            const range = selection.getRangeAt(0);
            const element = elementFromRangeContainer(range.commonAncestorContainer);
            const block = element ? element.closest(selectableBlockSelector) : null;
            clearCustomHighlights();
            if (block) {
              block.classList.add("magreader-selected-block");
            }
            setPendingSelection(text, "sentence");
            return true;
          }

          function targetMatchesPendingSelection(target) {
            if (!pendingText || !target || !target.closest) { return false; }
            const explicit = target.closest(".magreader-selected-text, .magreader-selected-block");
            if (explicit) { return true; }
            return false;
          }

          window.magReaderCommitPendingSelection = commitPendingSelection;

          function scheduleNativeSelectionPost() {
            if (suppressNativeSelection) { return; }
            if (nativeSelectionTimer) { clearTimeout(nativeSelectionTimer); }
            nativeSelectionTimer = setTimeout(function() {
              if (suppressNativeSelection) { return; }
              const selection = window.getSelection && window.getSelection();
              const text = cleanText(selection ? selection.toString() : "");
              if (text) {
                if (text === lastNativeSelectionText) { return; }
                lastNativeSelectionText = text;
                if (text.length < 12 || !/\\s/.test(text)) { return; }
                if (/^[A-Za-z][A-Za-z'-]*$/.test(text)) { return; }
                previewNativeSelection(selection, text);
              }
            }, 420);
          }

          document.addEventListener("click", function(event) {
            if (event.target && event.target.closest && event.target.closest("a, button, input, textarea, select")) {
              return;
            }
            if (Date.now() < suppressClickUntil) {
              return;
            }
            if (targetMatchesPendingSelection(event.target)) {
              if (commitPendingSelection()) {
                event.preventDefault();
                return;
              }
            }
            if (pendingText) {
              if (previewWordAtPoint(event.clientX, event.clientY)) {
                event.preventDefault();
                return;
              }
              clearPendingSelection();
              event.preventDefault();
              return;
            }
            if (previewWordAtPoint(event.clientX, event.clientY)) {
              event.preventDefault();
              return;
            }
          }, true);

          document.addEventListener("touchstart", function(event) {
            if (event.touches && event.touches.length > 1) {
              clearPendingSelection();
              return;
            }
            if (!event.touches || event.touches.length !== 1) { return; }
            const touch = event.touches[0];
            longPressStart = { x: touch.clientX, y: touch.clientY };
            if (longPressTimer) { clearTimeout(longPressTimer); }
            longPressTimer = setTimeout(function() {
              longPressTimer = null;
              if (longPressStart && previewSentenceAtPoint(longPressStart.x, longPressStart.y)) {
                suppressClickUntil = Date.now() + 650;
              }
            }, 620);
          }, { capture: true, passive: true });

          document.addEventListener("touchmove", function(event) {
            if (!longPressStart || !event.touches || event.touches.length !== 1) { return; }
            const touch = event.touches[0];
            const dx = touch.clientX - longPressStart.x;
            const dy = touch.clientY - longPressStart.y;
            if ((dx * dx + dy * dy) > 144) {
              if (longPressTimer) { clearTimeout(longPressTimer); }
              longPressTimer = null;
              longPressStart = null;
            }
          }, { capture: true, passive: true });

          function cancelLongPressTimer() {
            if (longPressTimer) { clearTimeout(longPressTimer); }
            longPressTimer = null;
            longPressStart = null;
          }

          document.addEventListener("touchend", cancelLongPressTimer, { capture: true, passive: true });
          document.addEventListener("touchcancel", cancelLongPressTimer, { capture: true, passive: true });
          document.addEventListener("contextmenu", function(event) {
            event.preventDefault();
          }, true);

          document.addEventListener("selectionchange", scheduleNativeSelectionPost);
          document.addEventListener("mouseup", scheduleNativeSelectionPost);
        })();
        """
    }
}
