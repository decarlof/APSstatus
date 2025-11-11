import SwiftUI

struct StatusImagesView: View {
    private let imageURLs = [
        "https://www3.aps.anl.gov/asd/operations/gifplots/HDSRcomfort.png",
        "https://www3.aps.anl.gov/aod/blops/plots/WeekHistory.png"
    ]
    
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
                }
                
                HStack {
                    NavigationLink("About", destination: AboutView())
                    Spacer()
                    NavigationLink("Settings", destination: SettingsView())
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("APS Status")
        }
    }
}
