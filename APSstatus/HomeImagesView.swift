import SwiftUI

struct HomeImagesView: View {
    let urls: [URL] = [
        URL(string: "https://www3.aps.anl.gov/asd/operations/gifplots/HDSRcomfort.png")!,
        URL(string: "https://www3.aps.anl.gov/aod/blops/plots/WeekHistory.png")!
    ]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(urls, id: \.self) { url in
                RemoteImageView(url: url)
                    .frame(width: 120, height: 120)
                    .cornerRadius(8)
            }
        }
    }
}

#Preview {
    HomeImagesView()
}
