import Foundation
import zlib

// Port of Crypt.CryptStream..ctor (0x03b9c5fc) and Crypt.CryptStream.Decrypt (0x03b9c8ac)
// Plus WebConfig.ConfigRetriever.DoGetJsonFromCryptedStream (0x03b963ec)
public enum ZWCryptStream {
    /// Primary config / packs decryption key verified in UnityFramework ARM64 & 42_packs.bin
    public static let defaultConfigKey: UInt32 = 0x235C5CF4

    /// Decrypts a DAZW CryptStream byte payload using the 4-byte little-endian key:
    /// plain[i] = ((cipher[i] ^ key[i % 4]) - i + 56) & 0xFF
    // Port of Crypt.CryptStream.Decrypt (0x03b9c8ac)
    public static func decrypt(_ data: Data, key: UInt32 = defaultConfigKey) -> Data {
        let k0 = UInt8(key & 0xFF)
        let k1 = UInt8((key >> 8) & 0xFF)
        let k2 = UInt8((key >> 16) & 0xFF)
        let k3 = UInt8((key >> 24) & 0xFF)
        let keyBytes = [k0, k1, k2, k3]

        var output = Data(count: data.count)
        data.withUnsafeBytes { rawIn in
            output.withUnsafeMutableBytes { rawOut in
                guard let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress,
                      let outPtr = rawOut.bindMemory(to: UInt8.self).baseAddress else { return }
                for i in 0..<data.count {
                    let xored = Int(inPtr[i] ^ keyBytes[i & 3])
                    let decoded = (xored &- i &+ 56) & 0xFF
                    outPtr[i] = UInt8(decoded)
                }
            }
        }
        return output
    }

    /// Inverse transform of Crypt.CryptStream.Decrypt for local encoding / parity tests
    // Port of Crypt.CryptStream.Crypt (0x03b9ca9c)
    public static func encrypt(_ data: Data, key: UInt32 = defaultConfigKey) -> Data {
        let k0 = UInt8(key & 0xFF)
        let k1 = UInt8((key >> 8) & 0xFF)
        let k2 = UInt8((key >> 16) & 0xFF)
        let k3 = UInt8((key >> 24) & 0xFF)
        let keyBytes = [k0, k1, k2, k3]

        var output = Data(count: data.count)
        data.withUnsafeBytes { rawIn in
            output.withUnsafeMutableBytes { rawOut in
                guard let inPtr = rawIn.bindMemory(to: UInt8.self).baseAddress,
                      let outPtr = rawOut.bindMemory(to: UInt8.self).baseAddress else { return }
                for i in 0..<data.count {
                    let shifted = UInt8((Int(inPtr[i]) &+ i &- 56) & 0xFF)
                    outPtr[i] = shifted ^ keyBytes[i & 3]
                }
            }
        }
        return output
    }

    /// Decrypts a CryptStream-wrapped GZIP buffer and inflates it with system libz.
    // Port of WebConfig.ConfigRetriever.DoGetJsonFromCryptedStream (0x03b963ec)
    public static func decryptAndInflateGzip(_ data: Data, key: UInt32 = defaultConfigKey) throws -> Data {
        let decrypted = decrypt(data, key: key)
        return try gunzip(decrypted)
    }

    public enum InflateError: Error, Equatable {
        case emptyInput
        case streamInitFailed(Int32)
        case inflateFailed(Int32)
    }

    public static func gunzip(_ data: Data) throws -> Data {
        guard !data.isEmpty else { throw InflateError.emptyInput }

        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil

        // 15 + 32 enables automatic gzip/zlib header detection in zlib
        let initStatus = inflateInit2_(&stream, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else {
            throw InflateError.streamInitFailed(initStatus)
        }
        defer { inflateEnd(&stream) }

        var output = Data(capacity: max(data.count * 3, 4096))
        let chunkSize = 16_384
        var chunk = [UInt8](repeating: 0, count: chunkSize)

        var status: Int32 = Z_OK
        try data.withUnsafeBytes { rawInput in
            guard let inBase = rawInput.bindMemory(to: Bytef.self).baseAddress else { return }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inBase)
            stream.avail_in = uInt(data.count)

            repeat {
                let wroteCount = try chunk.withUnsafeMutableBufferPointer { outBuf -> Int in
                    stream.next_out = outBuf.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    status = zlib.inflate(&stream, Z_NO_FLUSH)
                    if status != Z_OK && status != Z_STREAM_END && status != Z_BUF_ERROR {
                        throw InflateError.inflateFailed(status)
                    }
                    return chunkSize - Int(stream.avail_out)
                }
                if wroteCount > 0 {
                    output.append(chunk, count: wroteCount)
                }
            } while status != Z_STREAM_END && stream.avail_in > 0
        }

        if status != Z_STREAM_END && status != Z_OK {
            throw InflateError.inflateFailed(status)
        }
        return output
    }
}

// Port of WebConfigLoader endpoint contract (0x03b60174)
public enum ZWWebConfigEndpoint {
    public static let baseURLFormat = "https://dazw-dl.mobirate.com/cfg/ios/%@.cfg"

    public static func configURL(name: String = "primarydata") -> URL? {
        URL(string: String(format: baseURLFormat, name))
    }
}
