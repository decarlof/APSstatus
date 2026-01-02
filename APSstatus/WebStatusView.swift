import SwiftUI

struct WebStatusView: View {
    // Injected URLs
    private let imageURLs: [String]

    // Injected PSS loader for beamline selection
    @ObservedObject var pssLoader: SDDSAllParamsLoader

    @State private var refreshID = UUID() // forces view rebuild on refresh
    @State private var zoomImage: IdentifiableImage? = nil

    // NEW: modal presentation state
    @State private var showAbout = false
    @State private var showSettings = false
    
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
                    Button("About") { showAbout = true }
                    Spacer()
                    Button("Settings") { showSettings = true }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("APS Status")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $zoomImage) { wrapped in
                ZoomableImageViewer(image: wrapped.image)
            }
            .sheet(isPresented: $showAbout) {
                NavigationStack {
                    SwipeDownToDismissHint(title: "About") {
                        AboutView()
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SwipeDownToDismissHint(title: "Settings") {
                        SettingsView(pssLoader: pssLoader)
                    }
                }
            }
        }
    }
}

struct SwipeDownToDismissHint<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                // Visual grabber like Apple's sheets
                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)

                Text("Swipe down to close")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)

            content
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
