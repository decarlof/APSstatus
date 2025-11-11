import SwiftUI

struct APSStatusImagesView: View {
    private let imageURLs = [
        "https://www3.aps.anl.gov/asd/operations/gifplots/HDSRcomfort.png",
        "https://www3.aps.anl.gov/aod/blops/plots/WeekHistory.png"
    ]
    
    var body: some View {
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
                        case .failure:
                            Text("Failed to load \(url)")
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .padding()
        }
    }
}
