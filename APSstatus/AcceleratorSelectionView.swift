//
//  AcceleratorSelectionView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 1/17/26.
//

import SwiftUI

struct AcceleratorSelectionView: View {
    // Persist selection using AppStorage (UserDefaults)
    @AppStorage(AcceleratorSelectionKeys.selectedAcceleratorPages)
    private var selectedPagesData: Data = Data()

    // In-memory selection
    @State private var selectedIDs: Set<String> = []

    private var allPages: [AcceleratorPageID] { AcceleratorPageID.curated }

    private let maxSelection: Int = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Select all / none row
                HStack {
                    Button("Select Top 3") { selectTop3() }
                    Spacer()
                    Button("Select None") { selectNone() }
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
                Text("Select the accelerator status pages you are interested in.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)

                Text("(up to 3)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)

                // All pages as boxes, arranged in rows of up to 6 (like shutter grid)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(allPages) { page in
                        acceleratorBox(page)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
        }
        .onAppear { loadSelection() }
        .navigationTitle("Accelerator Selection")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Page box
    private func acceleratorBox(_ page: AcceleratorPageID) -> some View {
        let isSelected = selectedIDs.contains(page.id)
        let selectionIsFull = selectedIDs.count >= maxSelection
        let canSelect = isSelected || !selectionIsFull

        let color = isSelected ? Color.green : Color.gray.opacity(0.4)

        return Button {
            toggle(page)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    )

                Text(page.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 30)
            .opacity(canSelect ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!canSelect)
    }

    // MARK: - Selection
    private func toggle(_ page: AcceleratorPageID) {
        if selectedIDs.contains(page.id) {
            selectedIDs.remove(page.id)
        } else {
            guard selectedIDs.count < maxSelection else { return }
            selectedIDs.insert(page.id)
        }
        saveSelection()
    }

    private func selectTop3() {
        selectedIDs = Set(allPages.prefix(maxSelection).map { $0.id })
        saveSelection()
    }

    private func selectNone() {
        selectedIDs.removeAll()
        saveSelection()
    }

    // MARK: - Persistence
    private func saveSelection() {
        // Enforce maxSelection deterministically (stable order)
        let allowedOrder = allPages.map { $0.id }
        let trimmed = allowedOrder.filter { selectedIDs.contains($0) }.prefix(maxSelection)
        selectedIDs = Set(trimmed)

        let idsArray = Array(selectedIDs)
        do {
            let data = try JSONEncoder().encode(idsArray)
            selectedPagesData = data
        } catch {
            print("Failed to encode accelerator selection: \(error)")
        }
    }

    private func loadSelection() {
        guard !selectedPagesData.isEmpty else {
            selectedIDs = []
            return
        }
        do {
            let decoded = try JSONDecoder().decode([String].self, from: selectedPagesData)

            // Enforce maxSelection deterministically (stable order)
            let allowedOrder = allPages.map { $0.id }
            let decodedSet = Set(decoded)
            let trimmed = allowedOrder.filter { decodedSet.contains($0) }.prefix(maxSelection)
            selectedIDs = Set(trimmed)
        } catch {
            print("Failed to decode accelerator selection: \(error)")
            selectedIDs = []
        }
    }
}
