import SwiftUI
import WebKit

struct MacReaderWebView: NSViewRepresentable {
    var article: Article
    var settings: ReaderSettings
    var onSelection: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "selection")
        controller.addUserScript(WKUserScript(source: selectionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        context.coordinator.currentHTML = renderedHTML
        view.loadHTMLString(renderedHTML, baseURL: nil)
        return view
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onSelection = onSelection
        let html = renderedHTML
        if context.coordinator.currentHTML != html {
            context.coordinator.currentHTML = html
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onSelection: (String) -> Void
        var currentHTML = ""

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
    }

    private var renderedHTML: String {
        let foreground = settings.isDark ? "#f3efe6" : "#1d1b18"
        let secondary = settings.isDark ? "#b8b2a7" : "#706a60"
        let accent = settings.isDark ? "#68d4ba" : "#0f766e"
        let page = settings.isDark ? "#101514" : "#f7f9f8"
        let panel = settings.isDark ? "#161d1c" : readerBackgroundColor
        let line = settings.isDark ? "#293735" : "#dfe7e4"
        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root { color-scheme: \(settings.isDark ? "dark" : "light"); }
            * { box-sizing: border-box; }
            body {
              margin: 0;
              padding: 34px 44px 80px;
              background: \(page);
              color: \(foreground);
              font-family: \(settings.fontFamily), Georgia, serif;
              font-size: \(settings.fontSize)px;
              line-height: \(settings.lineHeight);
              user-select: none;
            }
            main {
              max-width: 820px;
              margin: 0 auto;
              padding: clamp(28px, 4.2vw, 50px);
              border: 1px solid \(line);
              border-radius: 8px;
              background: \(panel);
              box-shadow: 0 16px 40px rgba(15, 32, 30, 0.08);
            }
            h1 {
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
              font-size: clamp(32px, 4vw, 46px);
              line-height: 1.08;
              letter-spacing: 0;
              margin: 0 0 10px;
            }
            .meta {
              color: \(secondary);
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              font-size: 13px;
              margin-bottom: 32px;
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
          </style>
        </head>
        <body>
          <main>
            <h1>\(escapeHTML(article.title))</h1>
            <div class="meta">\(escapeHTML(article.feedTitle ?? "Local feed")) · \(escapeHTML(article.difficulty))</div>
            \(sanitizeHTML(article.contentHtml))
          </main>
        </body>
        </html>
        """
    }

    private var readerBackgroundColor: String {
        if settings.isDark { return "#111315" }
        switch settings.readerBackground {
        case "white": return "#ffffff"
        case "warm": return "#fff7ed"
        case "green": return "#f0f7ef"
        case "gray": return "#f4f4f5"
        default: return "#fbfaf7"
        }
    }

    private var selectionScript: String {
        """
        (function() {
          if (window.__magReaderMacSelectionInstalled) { return; }
          window.__magReaderMacSelectionInstalled = true;
          let pendingText = "";
          let pendingNode = null;
          let longPressDelay = 430;
          let longPressMoveTolerance = 8;
          let longPressState = { timer: null, point: null, fired: false };

          function cleanText(text) {
            return String(text || "").replace(/\\s+/g, " ").trim();
          }

          function post(text) {
            const clean = cleanText(text);
            if (clean) { window.webkit.messageHandlers.selection.postMessage(clean); }
          }

          function clearHighlights() {
            document.querySelectorAll(".magreader-selected-text").forEach(function(mark) {
              const parent = mark.parentNode;
              if (!parent) { return; }
              while (mark.firstChild) { parent.insertBefore(mark.firstChild, mark); }
              parent.removeChild(mark);
              parent.normalize();
            });
            document.querySelectorAll(".magreader-selected-block").forEach(function(block) {
              block.classList.remove("magreader-selected-block");
            });
            pendingText = "";
            pendingNode = null;
          }

          function textNodeAt(x, y) {
            let range = null;
            if (document.caretRangeFromPoint) {
              range = document.caretRangeFromPoint(x, y);
            } else if (document.caretPositionFromPoint) {
              const position = document.caretPositionFromPoint(x, y);
              if (position) {
                range = document.createRange();
                range.setStart(position.offsetNode, position.offset);
              }
            }
            if (!range || !range.startContainer || range.startContainer.nodeType !== Node.TEXT_NODE) { return null; }
            return { node: range.startContainer, offset: range.startOffset };
          }

          function wordRange(point) {
            const info = textNodeAt(point.clientX, point.clientY);
            if (!info) { return null; }
            const text = info.node.textContent || "";
            const regex = /[A-Za-z][A-Za-z'-]*/g;
            let match;
            while ((match = regex.exec(text))) {
              const start = match.index;
              const end = start + match[0].length;
              if (info.offset >= start && info.offset <= end) {
                const range = document.createRange();
                range.setStart(info.node, start);
                range.setEnd(info.node, end);
                return range;
              }
            }
            return null;
          }

          function sentenceText(point) {
            const block = document.elementFromPoint(point.clientX, point.clientY)?.closest("p, li, blockquote, figcaption, h1, h2, h3, h4");
            if (!block) { return null; }
            const text = cleanText(block.textContent);
            if (!text) { return null; }
            return { block: block, text: text };
          }

          function highlightSentence(point) {
            const hit = sentenceText(point);
            clearHighlights();
            if (!hit) { return false; }
            hit.block.classList.add("magreader-selected-block");
            pendingNode = hit.block;
            pendingText = hit.text;
            return true;
          }

          function cancelLongPress() {
            if (longPressState.timer) {
              clearTimeout(longPressState.timer);
            }
            longPressState.timer = null;
            longPressState.point = null;
          }

          function highlightRange(range) {
            const mark = document.createElement("span");
            mark.className = "magreader-selected-text";
            try {
              range.surroundContents(mark);
              pendingNode = mark;
              pendingText = cleanText(mark.textContent);
            } catch (_) {
              pendingText = cleanText(range.toString());
            }
          }

          document.addEventListener("mousedown", function(event) {
            if (event.button !== 0) { return; }
            const point = { clientX: event.clientX, clientY: event.clientY };
            if (!sentenceText(point)) { return; }
            longPressState.fired = false;
            longPressState.point = point;
            longPressState.timer = setTimeout(function() {
              longPressState.fired = highlightSentence(point);
            }, longPressDelay);
          }, true);

          document.addEventListener("mousemove", function(event) {
            if (!longPressState.point) { return; }
            const dx = Math.abs(event.clientX - longPressState.point.clientX);
            const dy = Math.abs(event.clientY - longPressState.point.clientY);
            if (dx > longPressMoveTolerance || dy > longPressMoveTolerance) {
              cancelLongPress();
            }
          }, true);

          document.addEventListener("mouseup", function() {
            cancelLongPress();
          }, true);

          document.addEventListener("click", function(event) {
            if (longPressState.fired) {
              event.preventDefault();
              event.stopPropagation();
              longPressState.fired = false;
              return;
            }
            const point = { clientX: event.clientX, clientY: event.clientY };
            if (pendingNode && pendingNode.contains(event.target)) {
              post(pendingText);
              return;
            }
            const range = wordRange(point);
            if (!range) {
              clearHighlights();
              return;
            }
            clearHighlights();
            highlightRange(range);
          }, true);
        })();
        """
    }
}
