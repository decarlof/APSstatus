import SwiftUI

struct WebStatusView: View {
    // Injected URLs
    private let imageURLs: [String]

    // Injected PSS loader for beamline selection
    @ObservedObject var pssLoader: SDDSAllParamsLoader

    @State private var refreshID = UUID() // forces view rebuild on refresh
    @State private var zoomImage: IdentifiableImage? = nil
    
    init(imageURLs: [String], pssLoader: SDDSAllParamsLoader) {
        self.imageURLs = imageURLs
        self.pssLoader = pssLoader
    }

    var body: some View {
        NavigationStack {
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
                    NavigationLink("About", destination: AboutView())
                    Spacer()
                    NavigationLink("Settings") {
                        SettingsView(pssLoader: pssLoader)
                    }
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
}
