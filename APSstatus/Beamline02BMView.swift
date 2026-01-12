//
//  Beamline02BMView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 1/8/26.
//

import SwiftUI

struct Beamline02BMView: View {
    private let urlString = "https://www3.xray.aps.anl.gov/tomolog/02bm_monitor.png"

    @State private var refreshID = UUID()
    @State private var zoomImage: IdentifiableImage? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AsyncImage(url: URL(string: urlString)) { phase in
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
            .id(refreshID)
        }
        .refreshable {
            URLCache.shared.removeAllCachedResponses()
            refreshID = UUID()
        }
        .navigationTitle("02-BM")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $zoomImage) { wrapped in
            ZoomableImageViewer(image: wrapped.image)
        }
    }
}
