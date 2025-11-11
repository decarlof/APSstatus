import SwiftUI

struct RemoteImageView: View {
    let url: URL
    @State private var image: Image? = nil
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let image = image {
                image
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = Image(uiImage: uiImage)
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
}
