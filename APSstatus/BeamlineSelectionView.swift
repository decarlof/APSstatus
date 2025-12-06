//
//  BeamlineSelectionView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 12/6/25.
//

import SwiftUI

struct BeamlineSelectionView: View {
    // Loader for the PSS SDDS file (contains BM/ID keys)
    @ObservedObject var pssLoader: SDDSAllParamsLoader

    // Persist selection using AppStorage (UserDefaults)
    @AppStorage(BeamlineSelectionKeys.selectedBeamlines)
    private var selectedBeamlinesData: Data = Data()

    // In-memory selection
    @State private var selectedIDs: Set<String> = []

    private var allBeamlines: [BeamlineID] {
        pssLoader.availableBeamlines
    }

    var body: some View {
        Group {
            if pssLoader.items.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(pssLoader.statusText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .onAppear {
                    pssLoader.fetchStatus()
                    loadSelection()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {

                        // Select all / none row
                        HStack {
                            Button("Select All") {
                                selectAll()
                            }
                            Spacer()
                            Button("Select None") {
                                selectNone()
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal)

                        // Legend
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(width: 20, height: 14)
                                Text("Selected")
                                    .font(.caption2)
                            }

                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 20, height: 14)
                                Text("Not selected")
                                    .font(.caption2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                        // help text
                        Text("Select the beamlines you are interested in. If you would like a custom beamline status page, please provide the EPICS PVs for your beamline so they can be included in a future update.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                        // All beamlines as boxes, arranged in rows of up to 6 (like shutter grid)
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                            ForEach(allBeamlines) { bl in
                                beamlineBox(bl)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
                .onAppear {
                    // Ensure selection is loaded when data is available
                    loadSelection()
                }
            }
        }
        .navigationTitle("Beamline Selection")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Beamline box

    private func beamlineBox(_ bl: BeamlineID) -> some View {
        let isSelected = selectedIDs.contains(bl.id)
        let color = isSelected ? Color.green : Color.gray.opacity(0.4)

        return Button {
            toggle(bl)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )

                Text(bl.displayName) // e.g. "01-BM"
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 30)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection

    private func toggle(_ bl: BeamlineID) {
        if selectedIDs.contains(bl.id) {
            selectedIDs.remove(bl.id)
        } else {
            selectedIDs.insert(bl.id)
        }
        saveSelection()
    }

    private func selectAll() {
        selectedIDs = Set(allBeamlines.map { $0.id })
        saveSelection()
    }

    private func selectNone() {
        selectedIDs.removeAll()
        saveSelection()
    }

    // MARK: - Persistence

    private func saveSelection() {
        let idsArray = Array(selectedIDs)
        do {
            let data = try JSONEncoder().encode(idsArray)
            selectedBeamlinesData = data
        } catch {
            print("Failed to encode beamline selection: \(error)")
        }
    }

    private func loadSelection() {
        guard !selectedBeamlinesData.isEmpty else {
            selectedIDs = []
            return
        }
        do {
            let decoded = try JSONDecoder().decode([String].self, from: selectedBeamlinesData)
            selectedIDs = Set(decoded)
        } catch {
            print("Failed to decode beamline selection: \(error)")
            selectedIDs = []
        }
    }
}
