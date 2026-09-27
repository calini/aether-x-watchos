//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

nonisolated enum OggOpusError: Error, Equatable {
    case invalidPage
    case badChecksum
    case missingHeaders
    case notOpus
}

nonisolated struct OggOpusFile: Equatable, Sendable {
    let preSkip: UInt16
    let inputSampleRate: UInt32
    /// Audio packets, without the two header packets.
    let packets: [Data]
    /// The last page's granule: 48 kHz samples including pre-skip, so the real length is `granulePosition - preSkip`.
    let granulePosition: Int64
}

/// Writes a mono Ogg Opus stream (RFC 3533, RFC 7845).
nonisolated enum OggOpusWriter {
    static let vendor = "Element X watchOS"
    /// About 1 s of 20 ms packets.
    static let packetsPerPage = 50

    /// A complete Ogg Opus file. `frameCount` (48 kHz, excluding pre-skip) sets the final granule; ~1 s of packets per page.
    static func write(packets: [Data], preSkip: UInt16, frameCount: Int64, serialNumber: UInt32 = .random(in: .min ... .max)) -> Data {
        var stream = OggPageStream(serialNumber: serialNumber)
        stream.appendPage(OggPage(packet: opusHead(preSkip: preSkip)), flags: OggPage.beginningOfStream, granule: 0)
        // An empty stream ends on the tags page.
        stream.appendPage(OggPage(packet: opusTags()), flags: packets.isEmpty ? OggPage.endOfStream : 0, granule: 0)

        let finalGranule = Int64(preSkip) + frameCount
        var samples: Int64 = 0
        var page = OggPage()
        for (index, packet) in packets.enumerated() {
            samples += OpusPacket.sampleCount(of: packet)
            var offset = packet.startIndex
            while true {
                if page.isFull {
                    stream.appendPage(page)
                    page = OggPage(isContinued: offset > packet.startIndex)
                }
                let end = min(offset + 255, packet.endIndex)
                page.appendSegment(packet[offset..<end])
                offset = end
                if page.lacing.last != 255 {
                    // Pages before the last mustn't pass the trimmed end.
                    page.granule = min(samples, finalGranule)
                    page.completedPackets += 1
                    break
                }
            }
            if page.completedPackets == packetsPerPage, index < packets.count - 1 {
                stream.appendPage(page)
                page = OggPage()
            }
        }
        if !packets.isEmpty {
            stream.appendPage(page, flags: OggPage.endOfStream, granule: finalGranule)
        }
        return stream.data
    }

    // MARK: - Private

    private static func opusHead(preSkip: UInt16) -> Data {
        var head = Data("OpusHead".utf8)
        head.append(1) // Version
        head.append(1) // Channels
        head.appendLittleEndian(preSkip)
        head.appendLittleEndian(UInt32(48000)) // Input sample rate
        head.appendLittleEndian(Int16(0)) // Output gain
        head.append(0) // Channel mapping family
        return head
    }

    private static func opusTags() -> Data {
        var tags = Data("OpusTags".utf8)
        let vendor = Data(vendor.utf8)
        tags.appendLittleEndian(UInt32(vendor.count))
        tags.append(vendor)
        tags.appendLittleEndian(UInt32(0)) // User comment count
        return tags
    }
}

/// Reads an Ogg Opus stream, validating every page's CRC and reassembling packets across pages.
nonisolated enum OggOpusReader {
    static func read(_ data: Data) throws(OggOpusError) -> OggOpusFile {
        let bytes = [UInt8](data)
        var packets: [Data] = []
        var partialPacket: Data?
        var granule: Int64 = 0
        var serialNumber: UInt32?
        var offset = 0

        while offset < bytes.count {
            let page = try OggPageHeader(bytes: bytes, at: offset)
            defer { offset = page.end }
            // Only the first logical stream is followed.
            if serialNumber == nil { serialNumber = page.serialNumber }
            guard page.serialNumber == serialNumber else { continue }
            guard page.isContinued == (partialPacket != nil) else { throw .invalidPage }

            var segmentStart = page.bodyStart
            for lacingValue in page.lacing {
                let segmentEnd = segmentStart + Int(lacingValue)
                partialPacket = (partialPacket ?? Data()) + bytes[segmentStart..<segmentEnd]
                segmentStart = segmentEnd
                if lacingValue < 255, let packet = partialPacket {
                    packets.append(packet)
                    partialPacket = nil
                }
            }
            if page.granule != -1 { granule = page.granule }
        }
        guard partialPacket == nil else { throw .invalidPage }

        guard let head = packets.first else { throw .missingHeaders }
        let header = try OpusHeader(head)
        guard packets.count >= 2, packets[1].starts(with: Data("OpusTags".utf8)) else { throw .missingHeaders }
        return OggOpusFile(preSkip: header.preSkip,
                           inputSampleRate: header.inputSampleRate,
                           packets: Array(packets.dropFirst(2)),
                           granulePosition: granule)
    }
}

/// CRC-32 as Ogg defines it: polynomial 0x04C11DB7, initial value 0, no reflection, no final XOR.
nonisolated enum OggCRC {
    private static let table: [UInt32] = (0..<256).map { index in
        var crc = UInt32(index) << 24
        for _ in 0..<8 {
            crc = crc & 0x8000_0000 != 0 ? (crc << 1) ^ 0x04C1_1DB7 : crc << 1
        }
        return crc
    }

    static func checksum(_ bytes: some Collection<UInt8>) -> UInt32 {
        bytes.reduce(0) { crc, byte in (crc << 8) ^ table[Int((crc >> 24) ^ UInt32(byte))] }
    }
}

// MARK: - Private

private nonisolated struct OggPage {
    static let beginningOfStream: UInt8 = 0x02
    static let endOfStream: UInt8 = 0x04
    static let continued: UInt8 = 0x01

    var isContinued = false
    var lacing: [UInt8] = []
    var body = Data()
    /// -1 means no packet ends on this page.
    var granule: Int64 = -1
    var completedPackets = 0

    var isFull: Bool { lacing.count == 255 }

    init(isContinued: Bool = false) {
        self.isContinued = isContinued
    }

    /// A page holding one packet under 255 × 255 bytes.
    init(packet: Data) {
        var offset = packet.startIndex
        repeat {
            let end = min(offset + 255, packet.endIndex)
            appendSegment(packet[offset..<end])
            offset = end
        } while lacing.last == 255
        completedPackets = 1
    }

    mutating func appendSegment(_ segment: Data) {
        lacing.append(UInt8(segment.count))
        body.append(segment)
    }
}

private nonisolated struct OggPageStream {
    let serialNumber: UInt32
    private(set) var data = Data()
    private var sequenceNumber: UInt32 = 0

    init(serialNumber: UInt32) {
        self.serialNumber = serialNumber
    }

    mutating func appendPage(_ page: OggPage, flags: UInt8 = 0, granule: Int64? = nil) {
        var bytes = Data("OggS".utf8)
        bytes.append(0) // Version
        bytes.append(flags | (page.isContinued ? OggPage.continued : 0))
        bytes.appendLittleEndian(granule ?? page.granule)
        bytes.appendLittleEndian(serialNumber)
        bytes.appendLittleEndian(sequenceNumber)
        bytes.appendLittleEndian(UInt32(0)) // CRC, filled in below
        bytes.append(UInt8(page.lacing.count))
        bytes.append(contentsOf: page.lacing)
        bytes.append(page.body)

        let crc = OggCRC.checksum(bytes)
        bytes.replaceSubrange(22..<26, with: withUnsafeBytes(of: crc.littleEndian, Array.init))
        data.append(bytes)
        sequenceNumber += 1
    }
}

private nonisolated struct OggPageHeader {
    let isContinued: Bool
    let granule: Int64
    let serialNumber: UInt32
    let lacing: ArraySlice<UInt8>
    let bodyStart: Int
    let end: Int

    init(bytes: [UInt8], at offset: Int) throws(OggOpusError) {
        let headerSize = 27
        guard bytes.count - offset >= headerSize,
              bytes[offset..<offset + 4].elementsEqual("OggS".utf8),
              bytes[offset + 4] == 0 else { throw .invalidPage }
        let segmentCount = Int(bytes[offset + 26])
        bodyStart = offset + headerSize + segmentCount
        guard bodyStart <= bytes.count else { throw .invalidPage }
        lacing = bytes[offset + headerSize..<bodyStart]
        end = bodyStart + lacing.reduce(0) { $0 + Int($1) }
        guard end <= bytes.count else { throw .invalidPage }

        var page = bytes[offset..<end]
        let storedCRC = UInt32(littleEndian: page, at: offset + 22)
        page.replaceSubrange(offset + 22..<offset + 26, with: [0, 0, 0, 0])
        guard OggCRC.checksum(page) == storedCRC else { throw .badChecksum }

        isContinued = bytes[offset + 5] & OggPage.continued != 0
        granule = Int64(bitPattern: UInt64(littleEndian: bytes, at: offset + 6))
        serialNumber = UInt32(littleEndian: bytes, at: offset + 14)
    }
}

/// The fields of an `OpusHead` packet (RFC 7845 §5.1) that decoding needs.
private nonisolated struct OpusHeader {
    let preSkip: UInt16
    let inputSampleRate: UInt32

    init(_ packet: Data) throws(OggOpusError) {
        let bytes = [UInt8](packet)
        // Major version 0 (the upper nibble) is the only one defined.
        guard bytes.count >= 19, bytes.starts(with: "OpusHead".utf8), bytes[8] & 0xF0 == 0, bytes[9] > 0 else { throw .notOpus }
        preSkip = UInt16(littleEndian: bytes, at: 10)
        inputSampleRate = UInt32(littleEndian: bytes, at: 12)
    }
}

private nonisolated enum OpusPacket {
    /// Samples at 48 kHz, from the packet's TOC byte (RFC 6716 §3.1); 0 for a malformed packet.
    static func sampleCount(of packet: Data) -> Int64 {
        guard let toc = packet.first else { return 0 }
        let configuration = Int(toc >> 3)
        let frameSize: Int64 = switch configuration {
        case 0..<12: [480, 960, 1920, 2880][configuration % 4] // SILK: 10, 20, 40, 60 ms
        case 12..<16: [480, 960][configuration % 2] // Hybrid: 10, 20 ms
        default: [120, 240, 480, 960][configuration % 4] // CELT: 2.5, 5, 10, 20 ms
        }
        let frames: Int64 = switch toc & 0x03 {
        case 0: 1
        case 1, 2: 2
        default: packet.dropFirst().first.map { Int64($0 & 0x3F) } ?? 0
        }
        return frameSize * frames
    }
}

private nonisolated extension Data {
    mutating func appendLittleEndian(_ value: some FixedWidthInteger) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

private nonisolated extension UnsignedInteger where Self: FixedWidthInteger {
    /// Reads a little-endian value at the absolute index `offset`.
    init<Bytes: RandomAccessCollection<UInt8>>(littleEndian bytes: Bytes, at offset: Int) where Bytes.Index == Int {
        self = (offset..<offset + MemoryLayout<Self>.size).reversed().reduce(0) { $0 << 8 | Self(bytes[$1]) }
    }
}
