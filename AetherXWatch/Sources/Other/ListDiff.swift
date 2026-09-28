//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import MatrixRustSDK

/// A platform-neutral form of the SDK's vector diffs (`RoomListEntriesUpdate`, `TimelineDiff`, `LiveLocationShareUpdate`).
enum ListDiff<Element> {
    case append([Element])
    case clear
    case pushFront(Element)
    case pushBack(Element)
    case popFront
    case popBack
    case insert(index: Int, value: Element)
    case set(index: Int, value: Element)
    case remove(index: Int)
    case truncate(length: Int)
    case reset([Element])
}

extension ListDiff {
    init(_ update: RoomListEntriesUpdate, transform: (Room) -> Element) {
        switch update {
        case .append(let values): self = .append(values.map(transform))
        case .clear: self = .clear
        case .pushFront(let value): self = .pushFront(transform(value))
        case .pushBack(let value): self = .pushBack(transform(value))
        case .popFront: self = .popFront
        case .popBack: self = .popBack
        case .insert(let index, let value): self = .insert(index: Int(index), value: transform(value))
        case .set(let index, let value): self = .set(index: Int(index), value: transform(value))
        case .remove(let index): self = .remove(index: Int(index))
        case .truncate(let length): self = .truncate(length: Int(length))
        case .reset(let values): self = .reset(values.map(transform))
        }
    }

    init(_ diff: TimelineDiff, transform: (MatrixRustSDK.TimelineItem) -> Element) {
        switch diff {
        case .append(let values): self = .append(values.map(transform))
        case .clear: self = .clear
        case .pushFront(let value): self = .pushFront(transform(value))
        case .pushBack(let value): self = .pushBack(transform(value))
        case .popFront: self = .popFront
        case .popBack: self = .popBack
        case .insert(let index, let value): self = .insert(index: Int(index), value: transform(value))
        case .set(let index, let value): self = .set(index: Int(index), value: transform(value))
        case .remove(let index): self = .remove(index: Int(index))
        case .truncate(let length): self = .truncate(length: Int(length))
        case .reset(let values): self = .reset(values.map(transform))
        }
    }

    init(_ update: LiveLocationShareUpdate, transform: (LiveLocationShare) -> Element) {
        switch update {
        case .append(let values): self = .append(values.map(transform))
        case .clear: self = .clear
        case .pushFront(let value): self = .pushFront(transform(value))
        case .pushBack(let value): self = .pushBack(transform(value))
        case .popFront: self = .popFront
        case .popBack: self = .popBack
        case .insert(let index, let value): self = .insert(index: Int(index), value: transform(value))
        case .set(let index, let value): self = .set(index: Int(index), value: transform(value))
        case .remove(let index): self = .remove(index: Int(index))
        case .truncate(let length): self = .truncate(length: Int(length))
        case .reset(let values): self = .reset(values.map(transform))
        }
    }
}

extension Array {
    /// Applies a diff defensively: out-of-range indices are logged and ignored rather than crashing.
    mutating func apply(_ diff: ListDiff<Element>) {
        switch diff {
        case .append(let values):
            append(contentsOf: values)
        case .clear:
            removeAll()
        case .pushFront(let value):
            insert(value, at: 0)
        case .pushBack(let value):
            append(value)
        case .popFront:
            if !isEmpty { removeFirst() }
        case .popBack:
            if !isEmpty { removeLast() }
        case .insert(let index, let value):
            insert(value, at: Swift.min(Swift.max(index, 0), count))
        case .set(let index, let value):
            guard indices.contains(index) else { return MXLog.error("ListDiff set out of range: \(index)/\(count)") }
            self[index] = value
        case .remove(let index):
            guard indices.contains(index) else { return MXLog.error("ListDiff remove out of range: \(index)/\(count)") }
            remove(at: index)
        case .truncate(let length):
            if length < count { removeLast(count - length) }
        case .reset(let values):
            self = values
        }
    }
}
