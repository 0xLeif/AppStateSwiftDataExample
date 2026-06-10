import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - StatsView

/// A self-contained dashboard view that displays aggregated statistics over all SwiftData
/// records managed by the shared `labContainer`.
///
/// Demonstrates how to derive computed stats (totals, percent complete, per-priority
/// breakdown) from `Application.modelState` without any additional store objects.
///
/// The view is designed to be pushed onto an existing `NavigationStack` — it does not create
/// its own navigation container.
///
/// ```swift
/// // In a host SwiftUI app's NavigationStack:
/// StatsView()
/// ```
public struct StatsView: View {

    // MARK: - Properties

    @ModelState(\.allItems) private var allItems: [TodoItem]
    @ModelState(\.todoLists) private var todoLists: [TodoList]
    @ModelState(\.allTags) private var allTags: [Tag]

    // MARK: - Initialiser

    public init() {}

    // MARK: - Body

    public var body: some View {
        List {
            statsOverviewSection
            priorityBreakdownSection
            actionSection
        }
        .navigationTitle("Stats")
    }

    // MARK: - Sections

    /// Overall counts and completion progress.
    private var statsOverviewSection: some View {
        Section("Overview") {
            StatsTotalRow(label: "Total Items", value: totalItems)
            StatsTotalRow(label: "Completed", value: completedItems)
            StatsTotalRow(label: "Remaining", value: remainingItems)
            statsProgressRow
            StatsTotalRow(label: "Total Lists", value: todoLists.count)
            StatsTotalRow(label: "Total Tags", value: allTags.count)
        }
    }

    private var statsProgressRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Complete")
                    .font(.body)
                Spacer()
                Text(statsPercentText)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: statsCompletionFraction)
                .progressViewStyle(.linear)
                .tint(statsProgressColor)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Completion \(statsPercentText)")
    }

    /// Per-priority item counts for priorities 0–5.
    private var priorityBreakdownSection: some View {
        Section("Items by Priority") {
            ForEach(StatsPriorityLevel.allCases) { level in
                StatsPriorityRow(
                    level: level,
                    count: itemCount(forPriority: level.rawValue),
                    total: totalItems
                )
            }
        }
    }

    private var actionSection: some View {
        Section {
            Button("Seed Sample Data") {
                seedSampleData()
            }
            .accessibilityIdentifier("statsViewSeedButton")

            Button("Clear All", role: .destructive) {
                clearAllData()
            }
            .accessibilityIdentifier("statsViewClearButton")
        }
    }

    // MARK: - Derived Stats

    private var totalItems: Int { allItems.count }

    private var completedItems: Int { allItems.filter(\.isDone).count }

    private var remainingItems: Int { allItems.filter { !$0.isDone }.count }

    private var statsCompletionFraction: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }

    private var statsPercentText: String {
        let percent = Int((statsCompletionFraction * 100).rounded())
        return "\(percent)%"
    }

    private var statsProgressColor: Color {
        switch statsCompletionFraction {
        case 1.0: return .green
        case 0.5...: return .blue
        default: return .orange
        }
    }

    private func itemCount(forPriority priority: Int) -> Int {
        allItems.filter { $0.priority == priority }.count
    }

    // MARK: - Actions

    /// Inserts a varied set of sample `TodoItem`s, `TodoList`s, and `Tag`s.
    ///
    /// Designed so that the dashboard is non-empty and shows a realistic spread of
    /// priorities and completion states immediately after seeding.
    private func seedSampleData() {
        let context = $allItems.context

        let workList = TodoList(title: "Work")
        let personalList = TodoList(title: "Personal")
        context.insert(workList)
        context.insert(personalList)

        let tagUrgent = Tag(name: "urgent")
        let tagHome = Tag(name: "home")
        let tagWork = Tag(name: "work")
        context.insert(tagUrgent)
        context.insert(tagHome)
        context.insert(tagWork)

        let seedItems: [(String, Bool, Int, TodoList, [Tag])] = [
            ("Write unit tests",    false, 5, workList,     [tagUrgent, tagWork]),
            ("Fix critical bug",    true,  5, workList,     [tagUrgent]),
            ("Review pull request", false, 4, workList,     [tagWork]),
            ("Update docs",         true,  3, workList,     [tagWork]),
            ("Grocery shopping",    false, 2, personalList, [tagHome]),
            ("Call dentist",        false, 2, personalList, [tagHome]),
            ("Read book",           true,  1, personalList, []),
            ("Tidy desk",           false, 0, personalList, [tagHome]),
            ("Send weekly report",  false, 4, workList,     [tagWork, tagUrgent]),
            ("Archive emails",      true,  1, workList,     [tagWork]),
        ]

        for (title, isDone, priority, list, tags) in seedItems {
            let item = TodoItem(title: title, isDone: isDone, priority: priority)
            list.items.append(item)
            context.insert(item)
            item.tags = tags
        }

        try? context.save()
    }

    /// Deletes all `TodoItem`, `TodoList`, and `Tag` records from the shared container.
    private func clearAllData() {
        let context = $allItems.context
        for item in allItems { context.delete(item) }
        for list in todoLists { context.delete(list) }
        for tag in allTags { context.delete(tag) }
        try? context.save()
    }
}

// MARK: - StatsTotalRow

/// A labelled value row used in the overview section.
private struct StatsTotalRow: View {

    // MARK: Properties

    let label: String
    let value: Int

    // MARK: Body

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - StatsPriorityLevel

/// Represents one of the six valid priority levels (0–5) defined by the schema.
internal enum StatsPriorityLevel: Int, CaseIterable, Identifiable {
    case none     = 0
    case low      = 1
    case medium   = 2
    case elevated = 3
    case high     = 4
    case critical = 5

    internal var id: Int { rawValue }

    internal var displayName: String {
        switch self {
        case .none:     return "None (0)"
        case .low:      return "Low (1)"
        case .medium:   return "Medium (2)"
        case .elevated: return "Elevated (3)"
        case .high:     return "High (4)"
        case .critical: return "Critical (5)"
        }
    }

    internal var color: Color {
        switch self {
        case .none:     return .gray
        case .low:      return .blue
        case .medium:   return .teal
        case .elevated: return .yellow
        case .high:     return .orange
        case .critical: return .red
        }
    }
}

// MARK: - StatsPriorityRow

/// A row displaying the item count for a single priority level, with a proportional bar.
private struct StatsPriorityRow: View {

    // MARK: Properties

    let level: StatsPriorityLevel
    let count: Int
    let total: Int

    // MARK: Computed

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(level.displayName)
                    .font(.subheadline)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(level.color.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(level.color)
                        .frame(width: geometry.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.displayName): \(count) items")
    }
}

#endif
