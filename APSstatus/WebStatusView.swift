import SwiftUI

struct WebStatusView: View {
    // Injected URLs
    private let imageURLs: [String]

    @Binding var activeSheet: SDDSAllView.ActiveSheet?

    @State private var refreshID = UUID() // forces view rebuild on refresh
    @State private var zoomImage: IdentifiableImage? = nil

    init(imageURLs: [String], activeSheet: Binding<SDDSAllView.ActiveSheet?>) {
        self.imageURLs = imageURLs
        self._activeSheet = activeSheet
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(imageURLs, id: \.self) { url in
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().frame(height: 220)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(12)
                                    .shadow(radius: 3)
                                    .onTapGesture {
                                        zoomImage = IdentifiableImage(image: image)
                                    }
                            case .failure:
                                VStack {
                                    Image(systemName: "xmark.octagon")
                                        .font(.largeTitle)
                                        .foregroundColor(.red)
                                    Text("Failed to load image")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(height: 220)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding()
                .id(refreshID) // rebuild content to trigger AsyncImage reload
            }
            .refreshable {
                // Clear cache and force reload of AsyncImage
                URLCache.shared.removeAllCachedResponses()
                refreshID = UUID()
            }

            HStack {
                Button("About") { activeSheet = .about }
                Spacer()
                Button("Settings") { activeSheet = .settings }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("APS Status")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $zoomImage) { wrapped in
            ZoomableImageViewer(image: wrapped.image)
        }
    }
}
