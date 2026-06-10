import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - QueryLiveListView

/// A self-contained screen demonstrating native SwiftData `@Query` as a reactive
/// contrast to AppState's `@ModelState`.
///
/// `@Query` binds directly to the `ModelContainer` injected by the host app via
/// `.modelContainer(...)`, and re-renders the list automatically whenever the
/// persistent store changes — without any manual observation or store object.
/// `@ModelState` provides the same reactivity through AppState's dependency system,
/// letting you control the container via `Application.override` in tests.
///
/// ### Integration
/// Present this view inside the host app's `NavigationStack`; it sets its own
/// `.navigationTitle` and needs no outer navigation container.
///
/// ```swift
/// // In the host app's tab or navigation destination:
/// QueryLiveListView()
/// ```
public struct QueryLiveListView: View {

    // MARK: - Properties

    /// Live, auto-updating list of all `TodoItem`s sorted by title.
    ///
    /// SwiftData re-fetches and re-renders this whenever the underlying store changes,
    /// including inserts made via `@Environment(\.modelContext)` in this same view.
    @Query(sort: \TodoItem.title)
    private var items: [TodoItem]

    /// The context provided by the host app's `.modelContainer(...)` environment modifier.
    ///
    /// Used to insert and delete `TodoItem`s without routing through AppState.
    @Environment(\.modelContext) private var context

    /// The current value of the new-item text field.
    @State private var newItemTitle: String = ""

    // MARK: - Initialiser

    /// Creates a `QueryLiveListView`.
    public init() {}

    // MARK: - Body

    public var body: some View {
        List {
            queryExplanationSection
            addItemSection
            liveItemsSection
        }
        .navigationTitle("Live @Query")
    }

    // MARK: - Sections

    /// A caption explaining the `@Query` vs `@ModelState` contrast.
    private var queryExplanationSection: some View {
        Section {
            QueryLiveCaptionView()
        }
    }

    /// A text field and Add button that insert a `TodoItem` directly via `modelContext`.
    private var addItemSection: some View {
        Section("Add Item") {
            HStack {
                TextField("New item title…", text: $newItemTitle)
                    .accessibilityIdentifier("QueryLiveListView.titleField")
                    .onSubmit { commitNewItem() }
                Button("Add", action: commitNewItem)
                    .accessibilityIdentifier("QueryLiveListView.addButton")
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    /// The reactive list of `TodoItem` rows, populated directly from `@Query`.
    private var liveItemsSection: some View {
        Section("Items (\(items.count))") {
            if items.isEmpty {
                Text("No items yet — add one above.")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                ForEach(items, id: \.persistentModelID) { item in
                    QueryLiveItemRowView(item: item)
                }
                .onDelete(perform: deleteItems)
            }
        }
    }

    // MARK: - Actions

    /// Inserts a `TodoItem` into the host-provided `modelContext` and saves.
    ///
    /// The `@Query` above picks up the new record automatically — no manual
    /// refresh or AppState call needed.
    @MainActor
    private func commitNewItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed)
        context.insert(item)
        try? context.save()
        newItemTitle = ""
    }

    /// Removes items at the given offsets from the `modelContext` and saves.
    ///
    /// - Parameter offsets: The index set identifying which rows to delete.
    @MainActor
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            context.delete(items[index])
        }
        try? context.save()
    }
}

// MARK: - QueryLiveCaptionView

/// A short explanatory caption contrasting native `@Query` with AppState's `@ModelState`.
///
/// Extracted into its own value type so `QueryLiveListViewTests` can locate it by type.
public struct QueryLiveCaptionView: View {

    // MARK: - Initialiser

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Native @Query", systemImage: "bolt.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.blue)

            Text(
                "@Query binds directly to the ModelContainer in the SwiftUI environment " +
                "and refreshes this list automatically. AppState's @ModelState provides " +
                "the same reactivity while letting you swap the container at test-time " +
                "via Application.override."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - QueryLiveItemRowView

/// A single row in the `QueryLiveListView` list, showing a `TodoItem`'s title and done state.
public struct QueryLiveItemRowView: View {

    // MARK: - Properties

    /// The item displayed by this row.
    public let item: TodoItem

    // MARK: - Initialiser

    /// Creates a `QueryLiveItemRowView`.
    ///
    /// - Parameter item: The `TodoItem` to display.
    public init(item: TodoItem) {
        self.item = item
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isDone ? .green : .secondary)

            Text(item.title)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .secondary : .primary)

            Spacer()
        }
    }
}

#endif
