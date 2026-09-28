//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
@testable import AetherXWatch
import Testing

@Suite
struct OggOpusTests {
    /// "123456789" → 0x89A1897F is the published check value for CRC-32/OGG.
    @Test
    func crcKnownVector() throws {
        let checkInput = Array("123456789".utf8)
        #expect(referenceCRC(checkInput) == 0x89A1897F)
        #expect(OggCRC.checksum(checkInput) == 0x89A1897F)

        // The OpusHead page written by ffmpeg/libopus stores its CRC (0x72B52802) at bytes 22..<26.
        var headPage = try Array(#require(Data(hex: ffmpegOpusFileHex)).prefix(47))
        #expect(UInt32(littleEndianBytes: headPage[22..<26]) == 0x72B52802)
        headPage.replaceSubrange(22..<26, with: [0, 0, 0, 0])
        #expect(referenceCRC(headPage) == 0x72B52802)
        #expect(OggCRC.checksum(headPage) == 0x72B52802)
    }

    @Test
    func readsAThirdPartyFile() throws {
        let file = try OggOpusReader.read(#require(Data(hex: ffmpegOpusFileHex)))

        #expect(file.preSkip == 312)
        #expect(file.inputSampleRate == 48000)
        #expect(file.packets.map(\.count) == [95, 66, 59, 56, 59, 47])
        #expect(file.granulePosition == 5112)
    }

    @Test(arguments: [0, 1, 120])
    func roundTripsPackets(count: Int) throws {
        let packets = (0..<count).map { makePacket(size: 1 + ($0 * 37) % 300) }
        let frameCount = Int64(max(count * 960 - 312 - 100, 0))

        let data = OggOpusWriter.write(packets: packets, preSkip: 312, frameCount: frameCount)
        let file = try OggOpusReader.read(data)

        #expect(file.packets == packets)
        #expect(file.preSkip == 312)
        #expect(file.granulePosition == (count == 0 ? 312 : 312 + frameCount))
        try expectValidPages(in: data)
    }

    @Test
    func lacingAndMultiPageRoundTrip() throws {
        let edgeSizes = [254, 255, 256, 510, 600]
        let packets = edgeSizes.map(makePacket) + (0..<130).map { _ in makePacket(size: 80) } + [makePacket(size: 60000)] + [makePacket(size: 255)]

        let data = OggOpusWriter.write(packets: packets, preSkip: 312, frameCount: Int64(packets.count * 960 - 400))
        let file = try OggOpusReader.read(data)
        #expect(file.packets == packets)

        let pages = try expectValidPages(in: data)
        let audioPages = pages.dropFirst(2)
        #expect(audioPages.count >= 4)
        #expect(audioPages.allSatisfy { $0.completedPackets <= OggOpusWriter.packetsPerPage })
        // 254, 255, 256, 510 and 600 bytes: a packet of a multiple of 255 bytes ends with a 0 lacing value.
        #expect(Array(pages[2].lacing.prefix(11)) == [254, 255, 0, 255, 1, 255, 255, 0, 255, 255, 90])

        // 60,000 bytes need 236 segments: the packet fills the rest of a shared page and ends on a continued one.
        let fullIndex = try #require(pages.firstIndex { $0.lacing.count == 255 })
        #expect(pages[fullIndex].lacing.last == 255)
        #expect(pages[fullIndex].granule != -1)
        #expect(pages[fullIndex + 1].flags & 0x01 == 0x01)
        #expect(pages.filter { $0.flags & 0x01 == 0x01 }.count == 1)

        let granules = audioPages.map(\.granule).filter { $0 != -1 }
        #expect(granules == granules.sorted())
    }

    /// Only a packet over the reader's cap can span a page where no packet ends, so this checks the writer alone.
    @Test
    func writerSpansAPageWhereNoPacketEnds() throws {
        let data = OggOpusWriter.write(packets: [makePacket(size: 80), makePacket(size: 140_000), makePacket(size: 80)], preSkip: 312, frameCount: 2500)

        let pages = try expectValidPages(in: data)
        #expect(pages.map(\.lacing.count) == [1, 1, 255, 255, 42])
        #expect(pages.map(\.granule) == [0, 0, 960, -1, 312 + 2500])
        #expect(pages.map { $0.flags & 0x01 } == [0, 0, 0, 0x01, 0x01])
        #expect(throws: OggOpusError.invalidPage) { try OggOpusReader.read(data) }
    }

    @Test
    func rejectsOversizedPackets() throws {
        let largest = makePacket(size: OggOpusReader.maximumPacketSize)
        let file = try OggOpusReader.read(OggOpusWriter.write(packets: [largest], preSkip: 312, frameCount: 600))
        #expect(file.packets == [largest])

        let oversized = OggOpusWriter.write(packets: [makePacket(size: OggOpusReader.maximumPacketSize + 1)], preSkip: 312, frameCount: 600)
        #expect(throws: OggOpusError.invalidPage) { try OggOpusReader.read(oversized) }
    }

    @Test
    func rejectsLyingPages() throws {
        let headers = makePage(body: makeOpusHead(), flags: 0x02) + makePage(body: makeOpusTags())
        let packet = makePacket(size: 10)

        let bodyPastTheEnd = makePage(body: packet, lacing: [200])
        let continuedFirstAudioPage = makePage(body: packet, flags: 0x01)
        let incompleteAtEnd = makePage(body: makePacket(size: 255), lacing: [255])
        let negativeGranule = makePage(body: packet, granule: -2)
        let endsInsidePreSkip = makePage(body: packet, granule: 311)
        for page in [bodyPastTheEnd, continuedFirstAudioPage, incompleteAtEnd, negativeGranule, endsInsidePreSkip] {
            #expect(throws: OggOpusError.invalidPage) { try OggOpusReader.read(headers + page) }
        }

        let file = try OggOpusReader.read(headers + makePage(body: packet, flags: 0x04, granule: 312))
        #expect(file.packets == [packet])
        #expect(file.granulePosition == 312)
    }

    @Test
    func acceptsOnlyMonoOrStereoFamilyZero() throws {
        let tags = makePage(body: makeOpusTags())
        let audio = makePage(body: makePacket(size: 10), flags: 0x04, granule: 1272)

        let stereo = try OggOpusReader.read(makePage(body: makeOpusHead(channels: 2), flags: 0x02) + tags + audio)
        #expect(stereo.channelCount == 2)

        for head in [makeOpusHead(mappingFamily: 1), makeOpusHead(channels: 0), makeOpusHead(channels: 3)] {
            #expect(throws: OggOpusError.notOpus) { try OggOpusReader.read(makePage(body: head, flags: 0x02) + tags + audio) }
        }
    }

    @Test
    func headerFields() throws {
        let data = OggOpusWriter.write(packets: [makePacket(size: 40)], preSkip: 0x0138, frameCount: 500, serialNumber: 0xCAFE_F00D)
        let pages = try expectValidPages(in: data)
        let bytes = [UInt8](data)

        #expect(pages[0].flags == 0x02)
        #expect(pages[0].granule == 0)
        #expect(pages[0].serial == 0xCAFE_F00D)
        #expect(pages[0].lacing == [19])
        #expect(Array(bytes[pages[0].bodyRange]) == Array("OpusHead".utf8) + [1, 1, 0x38, 0x01, 0x80, 0xBB, 0, 0, 0, 0, 0])

        let vendor = Array("Aether X watchOS".utf8)
        #expect(pages[1].flags == 0)
        #expect(pages[1].granule == 0)
        #expect(Array(bytes[pages[1].bodyRange]) == Array("OpusTags".utf8) + [UInt8(vendor.count), 0, 0, 0] + vendor + [0, 0, 0, 0])

        let file = try OggOpusReader.read(data)
        #expect(file.channelCount == 1)
        #expect(file.preSkip == 0x0138)
        #expect(file.inputSampleRate == 48000)
    }

    @Test
    func eosAndGranule() throws {
        let packets = (0..<51).map { _ in makePacket(size: 60) }
        let data = OggOpusWriter.write(packets: packets, preSkip: 312, frameCount: 48000)

        let pages = try expectValidPages(in: data)
        #expect(pages.map(\.granule) == [0, 0, 48000, 48312])
        #expect(pages.map { $0.flags & 0x04 } == [0, 0, 0, 0x04])
        #expect(try OggOpusReader.read(data).granulePosition == 48312)
    }

    @Test
    func rejectsCorruptChecksum() throws {
        var data = OggOpusWriter.write(packets: [makePacket(size: 100)], preSkip: 312, frameCount: 600)
        data[data.count - 10] ^= 0xFF

        #expect(throws: OggOpusError.badChecksum) { try OggOpusReader.read(data) }
    }

    @Test
    func rejectsNonOpus() throws {
        let vorbisHeader = Data([1] + Array("vorbis".utf8) + [UInt8](repeating: 0, count: 23))
        #expect(throws: OggOpusError.notOpus) { try OggOpusReader.read(makePage(body: vorbisHeader, flags: 0x02)) }

        let written = OggOpusWriter.write(packets: [makePacket(size: 100)], preSkip: 312, frameCount: 600)
        #expect(throws: OggOpusError.missingHeaders) { try OggOpusReader.read(written.prefix(47)) }
        #expect(throws: OggOpusError.missingHeaders) { try OggOpusReader.read(Data()) }
        #expect(throws: OggOpusError.invalidPage) { try OggOpusReader.read(Data("RIFF, not an Ogg file at all".utf8)) }
        #expect(throws: OggOpusError.invalidPage) { try OggOpusReader.read(written.dropLast(5)) }
    }

    @Test
    func decodesAnOpusCodecEncodingEndToEnd() throws {
        let source = try makeTone(seconds: 1)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: output)
        }

        let encoded = try OpusCodec.encode(fileAt: source)
        let data = OggOpusWriter.write(packets: encoded.packets, preSkip: encoded.preSkip, frameCount: encoded.frameCount)
        let file = try OggOpusReader.read(data)
        #expect(file.packets == encoded.packets)
        #expect(file.preSkip == encoded.preSkip)
        #expect(file.granulePosition == Int64(encoded.preSkip) + 48000)

        let duration = try OpusCodec.decode(packets: file.packets, preSkip: file.preSkip, to: output)
        #expect(abs(duration - 1) <= 0.02)
    }

    // MARK: - Helpers

    /// 0.1 s of a 440 Hz tone, encoded by ffmpeg 8 with libopus (bit-exact, no metadata): 3 pages, 6 packets, pre-skip 312.
    private let ffmpegOpusFileHex = """
    4f6767530002000000000000000000000000000000000228b57201134f707573486561640101380180bb00000000004f\
    6767530000000000000000000000000000010000004995be54012e4f707573546167730600000066666d706567010000\
    0014000000656e636f6465723d4c617663206c69626f7075734f6767530004f81300000000000000000000020000003a\
    6b5c69065f423b383b2f7881a75d6c9e99ac0000080ae05ad5119c443115057b3de67e1cb8f90d59595f21d0ba3aa58e\
    75383c1a181fb9faf16ad9f5d570914f0b381afe9843b0b543aaf0596be2f4350e0d0065c40d12e1e1726c418d329138\
    b2c8489480e5a5ea04789f6701e7fc954d4eaa18a719dfe55c59dffb6ea13365f5a8a5490de45777878f0a42d0924691\
    fd1fd43b703ff7d597a83856825225700bba963c1c0f4f41f789bd789ab2df759cfc4b3a457e285a7287c683883b1c47\
    2a162818134401ffba0f93c2b1e175d8a3fc94d16c4e8171b6f32023a79ff5d6e7f72cdd7c05789ab2df759cfc45edd7\
    339f1363df1013d90fefc0b7a178bc2768b989bf68afc88af0d90732a3c8a1e9d51e26c7dfc50ead776f594b134c789a\
    b2df759cfc4933bf4af7252368a68d200175769bed3be7a525aa12043feeebef464c96892058587f67f75fbf38defc56\
    97f829a76bf649e5047805a415f011e78862b1a6b060cbe0d49a234e82d9771ca4015f3bca47ff16056ccb1f2626097f\
    99bf61538e260e5c
    """

    private struct Page {
        let flags: UInt8
        let granule: Int64
        let serial: UInt32
        let sequence: UInt32
        let lacing: [UInt8]
        let bodyRange: Range<Int>

        var completedPackets: Int { lacing.count(where: { $0 < 255 }) }
    }

    /// Bit-at-a-time CRC-32/OGG (poly 0x04C11DB7, init 0, no reflection, no final XOR), independent of `OggCRC`'s table.
    private func referenceCRC(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0
        for byte in bytes {
            crc ^= UInt32(byte) << 24
            for _ in 0..<8 {
                crc = crc & 0x8000_0000 != 0 ? (crc << 1) ^ 0x04C1_1DB7 : crc << 1
            }
        }
        return crc
    }

    /// Parses every page independently of `OggOpusReader`, checking framing, CRCs and sequence numbers.
    @discardableResult
    private func expectValidPages(in data: Data) throws -> [Page] {
        let bytes = [UInt8](data)
        var pages: [Page] = []
        var offset = 0
        while offset < bytes.count {
            #expect(Array(bytes[offset..<offset + 4]) == Array("OggS".utf8))
            #expect(bytes[offset + 4] == 0)
            let segmentCount = Int(bytes[offset + 26])
            let lacing = Array(bytes[offset + 27..<offset + 27 + segmentCount])
            let bodyStart = offset + 27 + segmentCount
            let end = bodyStart + lacing.reduce(0) { $0 + Int($1) }
            try #require(end <= bytes.count)

            var zeroed = Array(bytes[offset..<end])
            zeroed.replaceSubrange(22..<26, with: [0, 0, 0, 0])
            #expect(referenceCRC(zeroed) == UInt32(littleEndianBytes: bytes[offset + 22..<offset + 26]))

            let page = Page(flags: bytes[offset + 5],
                            granule: Int64(bitPattern: UInt64(littleEndianBytes: bytes[offset + 6..<offset + 14])),
                            serial: UInt32(littleEndianBytes: bytes[offset + 14..<offset + 18]),
                            sequence: UInt32(littleEndianBytes: bytes[offset + 18..<offset + 22]),
                            lacing: lacing,
                            bodyRange: bodyStart..<end)
            #expect(page.sequence == UInt32(pages.count))
            #expect(page.serial == pages.first?.serial ?? page.serial)
            #expect(page.completedPackets > 0 || page.granule == -1)
            pages.append(page)
            offset = end
        }
        #expect(pages.first?.flags == 0x02)
        #expect(pages.last.map { $0.flags & 0x04 } == 0x04)
        return pages
    }

    /// A page (serial 0, sequence 0) with a correct CRC holding `body` as one packet, unless `lacing` says otherwise.
    private func makePage(body: Data, lacing: [UInt8]? = nil, flags: UInt8 = 0, granule: Int64 = 0) -> Data {
        let lacing = lacing ?? [UInt8](repeating: 255, count: body.count / 255) + [UInt8(body.count % 255)]
        let granuleBytes = (0..<8).map { UInt8(truncatingIfNeeded: UInt64(bitPattern: granule) >> ($0 * 8)) }
        var page = Array("OggS".utf8) + [0, flags] + granuleBytes + [UInt8](repeating: 0, count: 12) + [UInt8(lacing.count)] + lacing + body
        let crc = referenceCRC(page)
        page.replaceSubrange(22..<26, with: (0..<4).map { UInt8(truncatingIfNeeded: crc >> ($0 * 8)) })
        return Data(page)
    }

    /// Pre-skip 312, 48 kHz.
    private func makeOpusHead(channels: UInt8 = 1, mappingFamily: UInt8 = 0) -> Data {
        Data(Array("OpusHead".utf8) + [1, channels, 0x38, 0x01, 0x80, 0xBB, 0, 0, 0, 0, mappingFamily])
    }

    private func makeOpusTags() -> Data {
        Data(Array("OpusTags".utf8) + [0, 0, 0, 0, 0, 0, 0, 0])
    }

    /// A packet whose TOC byte (0xF8: CELT fullband, 20 ms, one frame) declares 960 samples.
    private func makePacket(size: Int) -> Data {
        Data([0xF8] + (1..<size).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ size) })
    }

    private func makeTone(seconds: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        let format = OpusCodec.pcmFormat
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let frames = AVAudioFrameCount(48000 * seconds)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        let samples = try #require(buffer.floatChannelData)
        buffer.frameLength = frames
        for index in 0..<Int(frames) {
            samples[0][index] = 0.5 * sin(2 * .pi * 440 * Float(index) / 48000)
        }
        try file.write(from: buffer)
        return url
    }
}

private extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}

private extension FixedWidthInteger {
    init(littleEndianBytes bytes: some Collection<UInt8>) {
        self = bytes.reversed().reduce(0) { $0 << 8 | Self($1) }
    }
}
