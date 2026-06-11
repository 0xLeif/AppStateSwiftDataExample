import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - QueryLiveListView

/// Native `@Query` reactive list — contrasts with `@ModelState` (same reactivity, swappable container).
///
/// ```swift
/// QueryLiveListView()
/// ```
public struct QueryLiveListView: View {

    // MARK: - Properties

    @Query(sort: \TodoItem.title) private var items: [TodoItem]
    @Environment(\.modelContext) private var context
    @State private var newItemTitle: String = ""

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

    private var queryExplanationSection: some View {
        Section {
            QueryLiveCaptionView()
        }
    }

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

    @MainActor
    private func commitNewItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(title: trimmed)
        context.insert(item)
        try? context.save()
        newItemTitle = ""
    }

    @MainActor
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            context.delete(items[index])
        }
        try? context.save()
    }
}

// MARK: - QueryLiveCaptionView

/// `@Query` vs `@ModelState` caption. Own type so tests can locate it.
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

/// Row showing a `TodoItem`'s done state and title.
public struct QueryLiveItemRowView: View {

    public let item: TodoItem

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
