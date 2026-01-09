//
//  Beamline32IDView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 1/8/26.
//

import SwiftUI

struct Beamline32IDView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("32-ID")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Work in progress")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("32-ID")
        .navigationBarTitleDisplayMode(.inline)
    }
}
