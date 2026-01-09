//
//  Beamline12BMView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 1/8/26.
//

import SwiftUI

struct Beamline12BMView: View {
    private let urlString = "https://12bm.xray.aps.anl.gov/images/12bm_monitor.jpg"

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
        .navigationTitle("12-BM")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $zoomImage) { wrapped in
            ZoomableImageViewer(image: wrapped.image)
        }
    }
}
