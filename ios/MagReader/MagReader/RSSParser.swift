import Foundation

final class FeedXMLParser: NSObject, XMLParserDelegate {
    private var feedTitle: String?
    private var siteUrl: String?
    private var items: [ParsedFeedItem] = []
    private var currentItem: PartialItem?
    private var currentElement = ""
    private var currentText = ""
    private var inItem = false
    private var inEntry = false

    func parse(_ data: Data) throws -> ParsedFeed {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError ?? MagReaderError.feedParseFailed
        }
        return ParsedFeed(title: feedTitle, siteUrl: siteUrl, items: items)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName.lowercased()
        currentText = ""
        if currentElement == "item" {
            inItem = true
            currentItem = PartialItem()
        }
        if currentElement == "entry" {
            inEntry = true
            currentItem = PartialItem()
        }
        if currentElement == "link" {
            if inEntry, let href = attributeDict["href"], currentItem?.link == nil {
                currentItem?.link = href
            } else if !inItem && !inEntry, let href = attributeDict["href"], siteUrl == nil {
                siteUrl = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) {
            currentText += text
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = elementName.lowercased()
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        defer {
            currentText = ""
            currentElement = ""
        }

        if inItem || inEntry {
            switch element {
            case "title":
                currentItem?.title = text
            case "link":
                if currentItem?.link == nil, !text.isEmpty {
                    currentItem?.link = text
                }
            case "guid", "id":
                currentItem?.guid = text
            case "creator", "author", "dc:creator":
                currentItem?.author = text
            case "pubdate", "published", "updated":
                currentItem?.publishedAt = decodeDate(text) ?? parseRFC822Date(text)
            case "description", "summary":
                currentItem?.summary = text
            case "content", "content:encoded":
                currentItem?.contentHtml = text
            case "item":
                finishCurrentItem()
                inItem = false
            case "entry":
                finishCurrentItem()
                inEntry = false
            default:
                break
            }
        } else {
            switch element {
            case "title" where feedTitle == nil:
                feedTitle = text
            case "link" where siteUrl == nil && !text.isEmpty:
                siteUrl = text
            default:
                break
            }
        }
    }

    private func finishCurrentItem() {
        guard let item = currentItem else { return }
        let title = item.title.nilIfBlank ?? "Untitled Article"
        items.append(
            ParsedFeedItem(
                title: title,
                link: item.link.nilIfBlank,
                guid: item.guid.nilIfBlank,
                author: item.author.nilIfBlank,
                publishedAt: item.publishedAt,
                summary: item.summary.nilIfBlank,
                contentHtml: item.contentHtml.nilIfBlank
            )
        )
        currentItem = nil
    }
}

private struct PartialItem {
    var title = ""
    var link: String?
    var guid: String?
    var author: String?
    var publishedAt: Date?
    var summary: String?
    var contentHtml: String?
}

private extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
