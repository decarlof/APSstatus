import SwiftUI

struct Beamline02BMView: View {
    private let baseURLString = "https://www3.xray.aps.anl.gov/tomolog/02bm_monitor.png"

    @State private var refreshToken = UUID()
    @State private var zoomImage: IdentifiableImage? = nil

    private var imageURL: URL? {
        var comps = URLComponents(string: baseURLString)
        var items = comps?.queryItems ?? []
        items.append(URLQueryItem(name: "t", value: refreshToken.uuidString))
        comps?.queryItems = items
        return comps?.url
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().frame(height: 240)

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
                        .frame(height: 240)

                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .padding()
        }
        .refreshable {
            // Cache-bust to force fresh content even if an upstream cache is stale
            refreshToken = UUID()
        }
        .navigationTitle("02-BM")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $zoomImage) { wrapped in
            ZoomableImageViewer(image: wrapped.image)
        }
    }
}
