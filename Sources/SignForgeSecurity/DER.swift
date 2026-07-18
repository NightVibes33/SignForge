import Foundation

enum DER {
    static func sequence(_ parts: [Data]) -> Data { tag(0x30, concat(parts)) }
    static func set(_ parts: [Data]) -> Data { tag(0x31, concat(parts)) }
    static func integer(_ value: UInt8) -> Data { tag(0x02, Data([value])) }
    static func null() -> Data { Data([0x05, 0x00]) }
    static func objectIdentifier(_ bytes: [UInt8]) -> Data { tag(0x06, Data(bytes)) }
    static func utf8String(_ value: String) -> Data { tag(0x0C, Data(value.utf8)) }
    static func bitString(_ value: Data) -> Data { tag(0x03, Data([0x00]) + value) }
    static func context0(_ value: Data) -> Data { tag(0xA0, value) }

    static func tag(_ tag: UInt8, _ value: Data) -> Data { Data([tag]) + length(value.count) + value }

    static func length(_ count: Int) -> Data {
        if count < 128 { return Data([UInt8(count)]) }
        var value = count
        var bytes: [UInt8] = []
        while value > 0 { bytes.insert(UInt8(value & 0xff), at: 0); value >>= 8 }
        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }

    static func concat(_ parts: [Data]) -> Data { parts.reduce(Data(), +) }
}
