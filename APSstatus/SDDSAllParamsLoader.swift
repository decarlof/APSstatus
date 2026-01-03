import Foundation
import Combine
import Gzip

@MainActor
final class SDDSAllParamsLoader: ObservableObject {
    @Published var statusText: String = "Loading…"
    @Published var items: [(description: String, value: String)] = []

    private let urlString: String

    // NEW: cancel in-flight fetches to avoid overlap
    private var fetchTask: Task<Void, Never>?

    init(urlString: String) {
        self.urlString = urlString
    }

    func fetchStatus() {
        // NEW: cancel any in-flight request
        fetchTask?.cancel()

        guard let url = URL(string: urlString) else {
            statusText = "Invalid URL"
            return
        }

        // NEW: reflect refresh state immediately
        statusText = "Loading…"

        fetchTask = Task {
            do {
                let (compressedData, response) = try await URLSession.shared.data(from: url)
                try Task.checkCancellation()

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    statusText = "Failed to download (status \(http.statusCode))"
                    return
                }

                // Decompress + parse off the main thread
                let parsedItems = try await Task.detached(priority: .userInitiated) { () -> [(String, String)] in
                    let decompressed = try compressedData.gunzipped()
                    return try SDDSAllParamsParser.parseAllParamsItems(decompressed)
                }.value
                try Task.checkCancellation()

                // Publish on main actor
                self.items = parsedItems
                self.statusText = "Loaded SDDS (\(parsedItems.count) items)"
            } catch is CancellationError {
                // NEW: silent cancel; don't overwrite UI with an error
            } catch {
                self.statusText = "Error: \(error.localizedDescription)"
                print("Detailed error: \(error)")
            }
        }
    }
}
