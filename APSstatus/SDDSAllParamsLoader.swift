import Foundation
import Combine
import Gzip

@MainActor
final class SDDSAllParamsLoader: ObservableObject {
    @Published var statusText: String = "Loading…"
    @Published var items: [(description: String, value: String)] = []

    private let urlString: String

    init(urlString: String) {
        self.urlString = urlString
    }

    func fetchStatus() {
        guard let url = URL(string: urlString) else {
            statusText = "Invalid URL"
            return
        }

        Task {
            do {
                let (compressedData, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    statusText = "Failed to download (status \(http.statusCode))"
                    return
                }

                // Decompress + parse off the main thread
                let parsedItems = try await Task.detached(priority: .userInitiated) { () -> [(String, String)] in
                    let decompressed = try compressedData.gunzipped()
                    // Fully qualified call to nonisolated static method
                    return try SDDSAllParamsParser.parseAllParamsItems(decompressed)
                }.value

                // Publish on main actor
                self.items = parsedItems
                self.statusText = "Loaded SDDS (\(parsedItems.count) items)"
            } catch {
                self.statusText = "Error: \(error.localizedDescription)"
                print("Detailed error: \(error)")
            }
        }
    }
}
