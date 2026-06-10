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

/// Demonstrates live sorting and filtering of `TodoItem` records driven entirely by
/// `FetchDescriptor` rebuilt on every control change.
///
/// Controls exposed:
/// - Sort key picker (`Title`, `Priority`, `Created`).
/// - Sort-order toggle (ascending / descending).
/// - "Hide completed" toggle.
/// - Minimum-priority stepper (0 – 5).
///
/// The view seeds a handful of varied items the first time it appears in an empty store
/// so the controls visibly change the list without any manual setup.
///
/// Present this view inside a host `NavigationStack`; it adds `.navigationTitle` itself.
///
/// ```swift
/// NavigationStack {
///     SortFilterView()
/// }
/// ```
@MainActor
public struct SortFilterView: View {

    // MARK: - Properties

    /// The result of the most-recent `FetchDescriptor` execution.
    @State private var sortFilterItems: [TodoItem] = []

    /// The field used as the primary sort key.
    @State private var sortFilterSortKey: SortFilterSortKey = .title

    /// Whether the sort order is ascending.
    @State private var sortFilterAscending: Bool = true

    /// When `true`, completed items are excluded from results.
    @State private var sortFilterHideCompleted: Bool = false

    /// The minimum `priority` an item must have to appear in results (0 = show all).
    @State private var sortFilterMinPriority: Int = 0

    // MARK: - Initialiser

    /// Creates a `SortFilterView`.
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

    /// Builds a `FetchDescriptor<TodoItem>` from current control state and executes it
    /// against the shared lab container's `mainContext`.
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

    /// Inserts a small, varied set of seed items when the store is empty so the controls
    /// have visible data to sort and filter on first launch.
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

/// A compact row used by `SortFilterView` to display a single `TodoItem`.
public struct SortFilterRowView: View {

    // MARK: Properties

    /// The item to display.
    public let item: TodoItem

    // MARK: Initialiser

    /// Creates a `SortFilterRowView`.
    ///
    /// - Parameter item: The `TodoItem` to render.
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
