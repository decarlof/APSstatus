import SwiftUI

struct WebStatusView: View {
    private let imageURLs: [String]
    @Binding var activeSheet: SDDSAllView.ActiveSheet?

    @State private var refreshToken = UUID()
    @State private var zoomImage: IdentifiableImage? = nil

    init(imageURLs: [String], activeSheet: Binding<SDDSAllView.ActiveSheet?>) {
        self.imageURLs = imageURLs
        self._activeSheet = activeSheet
    }

    private func bustedURL(_ urlString: String) -> URL? {
        var comps = URLComponents(string: urlString)
        var items = comps?.queryItems ?? []
        items.append(URLQueryItem(name: "t", value: refreshToken.uuidString))
        comps?.queryItems = items
        return comps?.url
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(imageURLs, id: \.self) { url in
                        AsyncImage(url: bustedURL(url)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().frame(height: 220)
                            case .success(let image):
                                image.resizable().scaledToFit()
                                    .cornerRadius(12).shadow(radius: 3)
                                    .onTapGesture { zoomImage = IdentifiableImage(image: image) }
                            case .failure:
                                VStack {
                                    Image(systemName: "xmark.octagon")
                                        .font(.largeTitle).foregroundColor(.red)
                                    Text("Failed to load image")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                .frame(height: 220)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                refreshToken = UUID()
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
