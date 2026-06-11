import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - ItemSearchView

/// Live `#Predicate<TodoItem>` search using `localizedStandardContains`.
///
/// ```swift
/// ItemSearchView()
/// ```
@MainActor
public struct ItemSearchView: View {

    // MARK: - Properties

    @State private var searchText: String = ""
    @State private var matchedItems: [TodoItem] = []
    @State private var isLoading: Bool = true

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

/// Result count header for the search list.
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

/// Search result row: completion state, title, and priority badge.
@MainActor
public struct ItemSearchResultRow: View {

    // MARK: Properties

    public let item: TodoItem

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
