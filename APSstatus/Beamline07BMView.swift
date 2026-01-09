//
//  Beamline07BMView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 1/8/26.
//

import SwiftUI

struct Beamline07BMView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("07-BM")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Work in progress")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("07-BM")
        .navigationBarTitleDisplayMode(.inline)
    }
}
