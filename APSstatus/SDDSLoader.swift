import Foundation
import Compression
import Combine

class SDDSLoader: ObservableObject {
    @Published var statusText: String = "Loading…"

    func fetchAndDecompressSDDS() {
        guard let url = URL(string: "https://ops.aps.anl.gov/sddsStatus/mainStatus.sdds.gz") else {
            statusText = "Invalid URL"
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.statusText = "Download error: \(error.localizedDescription)"
                }
                return
            }

            guard let compressedData = data else {
                DispatchQueue.main.async {
                    self.statusText = "No data received"
                }
                return
            }

            // Decompress gzip data
            guard let decompressedData = self.decompressGzip(data: compressedData) else {
                DispatchQueue.main.async {
                    self.statusText = "Decompression failed"
                }
                return
            }

            // For now, just show byte count
            DispatchQueue.main.async {
                self.statusText = "Decompressed \(decompressedData.count) bytes"
            }

            // Later: parse SDDS binary structure here
        }

        task.resume()
    }

    private func decompressGzip(data: Data) -> Data? {
        return data.withUnsafeBytes { (srcBuffer: UnsafeRawBufferPointer) -> Data? in
            guard let srcPtr = srcBuffer.baseAddress else { return nil }

            let dstBufferSize = 10 * 1024 * 1024 // 10 MB
            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstBufferSize)
            defer { dstBuffer.deallocate() }

            let decompressedSize = compression_decode_buffer(
                dstBuffer,
                dstBufferSize,
                srcPtr.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB // gzip uses zlib header
            )

            guard decompressedSize > 0 else { return nil }
            return Data(bytes: dstBuffer, count: decompressedSize)
        }
    }
}
