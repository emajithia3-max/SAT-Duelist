import SwiftUI

// MARK: - Topic Picker View
// Select a specific topic within a section

struct TopicPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let section: SATSection
    let topics: [String]
    @Binding var selectedTopic: String?

    @State private var searchText = ""

    private var filteredTopics: [String] {
        if searchText.isEmpty {
            return topics
        }
        return topics.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        CinematicContainer {
            VStack(spacing: 0) {
                // Header
                headerSection

                // Search bar
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Topic list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        // Clear selection option
                        if selectedTopic != nil {
                            clearSelectionButton
                        }

                        // Topics
                        ForEach(filteredTopics, id: \.self) { topic in
                            TopicRow(
                                topic: topic,
                                isSelected: selectedTopic == topic
                            ) {
                                selectTopic(topic)
                            }
                        }

                        if filteredTopics.isEmpty {
                            noResultsView
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Button {
                HapticsManager.shared.buttonPress()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(DesignSystem.Colors.elevated)
                    )
            }

            Spacer()

            VStack(spacing: 4) {
                Text("Select Topic")
                    .font(DesignSystem.Typography.screenTitle())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(section.displayName)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textMuted)
            }

            Spacer()

            // Done button
            Button {
                HapticsManager.shared.buttonPress()
                dismiss()
            } label: {
                Text("Done")
                    .font(DesignSystem.Typography.button())
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            .frame(width: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignSystem.Colors.textMuted)

            TextField("Search topics", text: $searchText)
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textMuted)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Clear Selection Button

    private var clearSelectionButton: some View {
        Button {
            HapticsManager.shared.selectionChanged()
            withAnimation(DesignSystem.Animation.quick) {
                selectedTopic = nil
            }
        } label: {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textMuted)

                Text("Clear selection")
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(DesignSystem.Colors.elevated)
            )
        }
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(DesignSystem.Colors.textMuted)

            Text("No topics found")
                .font(DesignSystem.Typography.body())
                .foregroundColor(DesignSystem.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Actions

    private func selectTopic(_ topic: String) {
        HapticsManager.shared.selectionChanged()
        withAnimation(DesignSystem.Animation.quick) {
            if selectedTopic == topic {
                selectedTopic = nil
            } else {
                selectedTopic = topic
            }
        }
    }
}

// MARK: - Topic Row

struct TopicRow: View {
    let topic: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(topic)
                    .font(DesignSystem.Typography.body())
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                } else {
                    Circle()
                        .stroke(DesignSystem.Colors.cardBorder, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TopicPickerView(
        section: .math,
        topics: TopicsRegistry.mathTopics,
        selectedTopic: .constant(nil)
    )
}
