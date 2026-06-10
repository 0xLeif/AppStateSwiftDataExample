import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - ItemSearchView

/// A self-contained SwiftUI screen that demonstrates live search over SwiftData.
///
/// As the user types in the search bar, a `#Predicate<TodoItem>` fetch runs directly against
/// `Application.dependency(\.labContainer).mainContext`, filtering items whose titles contain
/// the query string (locale-aware, case-insensitive via `localizedStandardContains`). An empty
/// query shows all items. A result count header and `ContentUnavailableView` placeholders keep
/// the experience polished when no items or no matches are found.
///
/// The view is self-contained: no `NavigationStack` or `NavigationSplitView` — host apps
/// supply one. It seeds a small set of sample items when the store is empty so the screen is
/// non-blank on first open.
///
/// ```swift
/// // Inside a host NavigationStack:
/// ItemSearchView()
/// ```
@MainActor
public struct ItemSearchView: View {

    // MARK: - Properties

    /// The text the user has typed into the search bar.
    @State private var searchText: String = ""

    /// Items that match the current `searchText` (or all items when the query is empty).
    @State private var matchedItems: [TodoItem] = []

    /// `true` while the initial seed + first fetch is running.
    @State private var isLoading: Bool = true

    // MARK: - Initialiser

    /// Creates an `ItemSearchView`.
    public init() {}

    // MARK: - Body

    public var body: some View {
        itemSearchContent
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search items…")
            .onChange(of: searchText) { _, newValue in
                runSearch(query: newValue)
            }
            .task {
                seedIfNeeded()
                runSearch(query: searchText)
                isLoading = false
            }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var itemSearchContent: some View {
        if isLoading {
            ProgressView("Loading…")
        } else if matchedItems.isEmpty && searchText.isEmpty {
            itemSearchEmptyStoreView
        } else if matchedItems.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            itemSearchResultList
        }
    }

    private var itemSearchEmptyStoreView: some View {
        ContentUnavailableView(
            "No Items",
            systemImage: "tray",
            description: Text("Add items to a list to search them here.")
        )
    }

    private var itemSearchResultList: some View {
        List {
            ItemSearchResultHeader(count: matchedItems.count, query: searchText)
            ForEach(matchedItems, id: \.persistentModelID) { item in
                ItemSearchResultRow(item: item)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Search Logic

    /// Runs a `#Predicate<TodoItem>` fetch and updates `matchedItems`.
    ///
    /// An empty `query` matches all items. Non-empty queries use `localizedStandardContains`
    /// so the filter is locale-aware and case-insensitive.
    private func runSearch(query: String) {
        let context = Application.dependency(\.labContainer).mainContext
        let descriptor: FetchDescriptor<TodoItem>

        if query.isEmpty {
            descriptor = FetchDescriptor<TodoItem>(
                sortBy: [SortDescriptor(\.title)]
            )
        } else {
            let predicate = #Predicate<TodoItem> { item in
                item.title.localizedStandardContains(query)
            }
            descriptor = FetchDescriptor<TodoItem>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.title)]
            )
        }

        matchedItems = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Seeding

    /// Inserts a handful of sample `TodoItem`s when the main context holds no items at all.
    ///
    /// This ensures the screen is non-blank on first open without requiring the user to have
    /// already created data in another tab.
    private func seedIfNeeded() {
        let context = Application.dependency(\.labContainer).mainContext
        let existingCount = (try? context.fetchCount(FetchDescriptor<TodoItem>())) ?? 0
        guard existingCount == 0 else { return }

        let seeds: [(title: String, priority: Int)] = [
            ("Buy groceries", 1),
            ("Write unit tests", 3),
            ("Review pull request", 2),
            ("Update documentation", 1),
            ("Fix the login bug", 5),
            ("Sync with designer", 0),
            ("Plan sprint retrospective", 2),
        ]

        for seed in seeds {
            let item = TodoItem(title: seed.title, priority: seed.priority)
            context.insert(item)
        }

        try? context.save()
    }
}

// MARK: - ItemSearchResultHeader

/// A compact header that shows how many items match the current search query.
@MainActor
private struct ItemSearchResultHeader: View {

    // MARK: Properties

    let count: Int
    let query: String

    // MARK: Body

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(headerText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .listRowSeparator(.hidden)
        .padding(.vertical, 4)
    }

    // MARK: Helpers

    private var headerText: String {
        if query.isEmpty {
            return count == 1 ? "1 item" : "\(count) items"
        }
        return count == 1
            ? "1 result for \"\(query)\""
            : "\(count) results for \"\(query)\""
    }
}

// MARK: - ItemSearchResultRow

/// A single search result row displaying a `TodoItem`'s completion state, title, and priority.
@MainActor
public struct ItemSearchResultRow: View {

    // MARK: Properties

    public let item: TodoItem

    // MARK: Initialiser

    public init(item: TodoItem) {
        self.item = item
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: 12) {
            itemSearchCompletionIndicator
            itemSearchTitlePriorityStack
        }
        .padding(.vertical, 2)
    }

    // MARK: Sub-views

    private var itemSearchCompletionIndicator: some View {
        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(item.isDone ? Color.green : Color.secondary)
    }

    private var itemSearchTitlePriorityStack: some View {
        HStack {
            Text(item.title)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? Color.secondary : Color.primary)
            Spacer()
            if item.priority > 0 {
                itemSearchPriorityBadge
            }
        }
    }

    private var itemSearchPriorityBadge: some View {
        Text("P\(item.priority)")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(itemSearchPriorityColor.opacity(0.15))
            .foregroundStyle(itemSearchPriorityColor)
            .clipShape(Capsule())
    }

    private var itemSearchPriorityColor: Color {
        switch item.priority {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        case 2: return .blue
        default: return .gray
        }
    }
}

#endif
