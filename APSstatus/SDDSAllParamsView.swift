//
//  SDDSAllParamsView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 11/14/25.
//

import SwiftUI

struct SDDSAllParamsView: View {
    @StateObject private var loader: SDDSAllParamsLoader

    // Initialize with the file URL you want to display
    init(urlString: String, title: String = "SDDS Parameters") {
        _loader = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: urlString))
        self.title = title
    }

    private let title: String

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if loader.items.isEmpty {
                        Text(loader.statusText)
                            .foregroundColor(.gray)
                            .padding()
                            .onAppear { loader.fetchStatus() }
                    } else {
                        // Simple list of all Description : ValueString pairs
                        ForEach(Array(loader.items.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.description + ":")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(item.value)
                                    .multilineTextAlignment(.trailing)
                            }
                            Divider()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .refreshable {
                loader.fetchStatus()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
}
