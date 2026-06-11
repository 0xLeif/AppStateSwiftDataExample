import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - SortFilterSortKey

/// The field by which `SortFilterView` sorts `TodoItem` results.
public enum SortFilterSortKey: String, CaseIterable, Identifiable, Sendable {
    case title = "Title"
    case priority = "Priority"
    case created = "Created"

    public var id: String { rawValue }
}

// MARK: - SortFilterView

/// Live sort/filter of `TodoItem` records — `FetchDescriptor` rebuilt on every control change.
///
/// ```swift
/// NavigationStack { SortFilterView() }
/// ```
@MainActor
public struct SortFilterView: View {

    // MARK: - Properties

    @State private var sortFilterItems: [TodoItem] = []
    @State private var sortFilterSortKey: SortFilterSortKey = .title
    @State private var sortFilterAscending: Bool = true
    @State private var sortFilterHideCompleted: Bool = false
    @State private var sortFilterMinPriority: Int = 0

    public init() {}

    // MARK: - Body

    public var body: some View {
        List {
            sortFilterControlsSection
            sortFilterResultsSection
        }
        .navigationTitle("Sort & Filter")
        .onAppear {
            sortFilterSeedIfNeeded()
            sortFilterRefetch()
        }
    }

    // MARK: - Controls Section

    private var sortFilterControlsSection: some View {
        Section("Controls") {
            sortFilterSortKeyPicker
            sortFilterOrderToggle
            sortFilterHideCompletedToggle
            sortFilterMinPriorityRow
        }
    }

    private var sortFilterSortKeyPicker: some View {
        Picker("Sort by", selection: $sortFilterSortKey) {
            ForEach(SortFilterSortKey.allCases) { key in
                Text(key.rawValue).tag(key)
            }
        }
        .onChange(of: sortFilterSortKey) { _, _ in sortFilterRefetch() }
    }

    private var sortFilterOrderToggle: some View {
        Toggle(
            sortFilterAscending ? "Order: Ascending" : "Order: Descending",
            isOn: $sortFilterAscending
        )
        .onChange(of: sortFilterAscending) { _, _ in sortFilterRefetch() }
    }

    private var sortFilterHideCompletedToggle: some View {
        Toggle("Hide completed", isOn: $sortFilterHideCompleted)
            .onChange(of: sortFilterHideCompleted) { _, _ in sortFilterRefetch() }
    }

    private var sortFilterMinPriorityRow: some View {
        Stepper(
            "Min priority: \(sortFilterMinPriority)",
            value: $sortFilterMinPriority,
            in: 0...5
        )
        .onChange(of: sortFilterMinPriority) { _, _ in sortFilterRefetch() }
    }

    // MARK: - Results Section

    private var sortFilterResultsSection: some View {
        Section("\(sortFilterItems.count) result(s)") {
            if sortFilterItems.isEmpty {
                Text("No items match the current filters.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(sortFilterItems, id: \.persistentModelID) { item in
                    SortFilterRowView(item: item)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func sortFilterRefetch() {
        let context = Application.modelContext(\.labContainer)

        let order: SortOrder = sortFilterAscending ? .forward : .reverse
        let sortDescriptors: [SortDescriptor<TodoItem>] = switch sortFilterSortKey {
        case .title:    [SortDescriptor(\.title, order: order)]
        case .priority: [SortDescriptor(\.priority, order: order), SortDescriptor(\.title)]
        case .created:  [SortDescriptor(\.createdAt, order: order)]
        }

        var descriptor = FetchDescriptor<TodoItem>(sortBy: sortDescriptors)

        // Apply filters as in-memory post-fetch rather than #Predicate to stay compatible
        // with the existing in-memory container and avoid SwiftData predicate limitations
        // on relationship traversal in older OS versions.
        let hideCompleted = sortFilterHideCompleted
        let minPriority = sortFilterMinPriority

        let raw = (try? context.fetch(descriptor)) ?? []
        sortFilterItems = raw.filter { item in
            if hideCompleted, item.isDone { return false }
            if item.priority < minPriority { return false }
            return true
        }
    }

    private func sortFilterSeedIfNeeded() {
        let context = Application.modelContext(\.labContainer)
        let existing = (try? context.fetch(FetchDescriptor<TodoItem>())) ?? []
        guard existing.isEmpty else { return }

        let seeds: [(title: String, priority: Int, isDone: Bool)] = [
            ("Alpha task",   3, false),
            ("Beta task",    1, true),
            ("Gamma task",   5, false),
            ("Delta task",   0, false),
            ("Epsilon task", 4, true),
            ("Zeta task",    2, false),
        ]

        for seed in seeds {
            let item = TodoItem(title: seed.title, isDone: seed.isDone, priority: seed.priority)
            context.insert(item)
        }

        try? context.save()
    }
}

// MARK: - SortFilterRowView

/// A compact row for a `TodoItem` in `SortFilterView`.
public struct SortFilterRowView: View {

    // MARK: Properties

    /// The item to display.
    public let item: TodoItem

    public init(item: TodoItem) {
        self.item = item
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isDone ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? Color.secondary : Color.primary)

                Text("Priority \(item.priority)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#endif
