import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - ItemEditorView

/// Live `TodoItem` editor: tap a row to edit properties directly on the model.
///
/// ```swift
/// ItemEditorView()
/// ```
public struct ItemEditorView: View {

    // MARK: - Properties

    @StateObject private var store = ItemEditorStore()
    @State private var selectedItem: TodoItem?

    // MARK: - Initialiser

    public init() {}

    // MARK: - Body

    public var body: some View {
        itemList
            .navigationTitle("Edit")
            .toolbar { addButton }
            .sheet(item: $selectedItem) { item in
                ItemEditorDetailSheet(item: item, store: store)
            }
            .onAppear { store.seedIfEmpty() }
    }

    // MARK: - Sub-views

    private var itemList: some View {
        List {
            ForEach(store.items, id: \.persistentModelID) { item in
                ItemEditorRowView(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedItem = item }
            }
            .onDelete { offsets in
                offsets.map { store.items[$0] }.forEach { store.delete($0) }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var addButton: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                store.addItem()
                selectedItem = store.items.last
            } label: {
                Label("Add Item", systemImage: "plus")
            }
        }
    }
}

// MARK: - ItemEditorRowView

/// Row: title, completion, and priority badge.
public struct ItemEditorRowView: View {

    // MARK: - Properties

    public let item: TodoItem

    // MARK: - Initialiser

    public init(item: TodoItem) {
        self.item = item
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isDone ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)

                if let due = item.dueDate {
                    Text(due, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.priority > 0 {
                ItemEditorPriorityBadge(priority: item.priority)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ItemEditorPriorityBadge

/// Capsule badge for numeric priority.
public struct ItemEditorPriorityBadge: View {

    // MARK: - Properties

    public let priority: Int

    // MARK: - Initialiser

    public init(priority: Int) {
        self.priority = priority
    }

    // MARK: - Body

    public var body: some View {
        Text("P\(priority)")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Private Helpers

    private var color: Color {
        switch priority {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        case 2: return .blue
        default: return .gray
        }
    }
}

// MARK: - ItemEditorDetailSheet

/// Form for editing all `TodoItem` fields; saves on each change.
public struct ItemEditorDetailSheet: View {

    // MARK: - Properties

    public let item: TodoItem
    public let store: ItemEditorStore

    @State private var title: String
    @State private var priority: Int
    @State private var isDone: Bool
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    @Environment(\.dismiss) private var dismiss

    // MARK: - Initialiser

    public init(item: TodoItem, store: ItemEditorStore) {
        self.item = item
        self.store = store
        _title = State(initialValue: item.title)
        _priority = State(initialValue: item.priority)
        _isDone = State(initialValue: item.isDone)
        _hasDueDate = State(initialValue: item.dueDate != nil)
        _dueDate = State(initialValue: item.dueDate ?? Date())
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Form {
                titleSection
                prioritySection
                completionSection
                dueDateSection
            }
            .navigationTitle("Edit Item")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: title) { _, newValue in
            commitTitle(newValue)
        }
        .onChange(of: priority) { _, newValue in
            commitPriority(newValue)
        }
        .onChange(of: isDone) { _, newValue in
            commitIsDone(newValue)
        }
        .onChange(of: hasDueDate) { _, enabled in
            commitDueDate(enabled ? dueDate : nil)
        }
        .onChange(of: dueDate) { _, newValue in
            guard hasDueDate else { return }
            commitDueDate(newValue)
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section("Title") {
            TextField("Item title", text: $title)
        }
    }

    private var prioritySection: some View {
        Section("Priority") {
            Stepper("Priority: \(priority)", value: $priority, in: 0...5)
            ItemEditorPriorityBadge(priority: priority)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var completionSection: some View {
        Section("Status") {
            Toggle("Completed", isOn: $isDone)
        }
    }

    @ViewBuilder
    private var dueDateSection: some View {
        Section("Due Date") {
            Toggle("Set due date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker(
                    "Due",
                    selection: $dueDate,
                    displayedComponents: [.date]
                )
            }
        }
    }

    // MARK: - Commit Helpers

    private func commitTitle(_ newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        item.title = trimmed
        store.save()
    }

    private func commitPriority(_ newPriority: Int) {
        item.priority = newPriority
        store.save()
    }

    private func commitIsDone(_ newIsDone: Bool) {
        item.isDone = newIsDone
        store.save()
    }

    private func commitDueDate(_ newDueDate: Date?) {
        item.dueDate = newDueDate
        store.save()
    }
}

// MARK: - ItemEditorStore

/// View-model for `ItemEditorView`: owns the `@ModelState` binding and minimal mutation surface.
@MainActor
public final class ItemEditorStore: ObservableObject {

    // MARK: - Properties

    /// All `TodoItem` records, ordered by title.
    @ModelState(\.allItems) public var items: [TodoItem]

    // MARK: - Initialiser

    public init() {}

    // MARK: - Public Interface

    public func addItem() {
        let item = TodoItem(title: "New Item")
        $items.insert(item)
    }

    public func delete(_ item: TodoItem) {
        $items.delete(item)
    }

    public func save() {
        $items.save()
    }

    public func seedIfEmpty() {
        guard items.isEmpty else { return }
        $items.insert(TodoItem(title: "Buy groceries", priority: 2))
        $items.insert(TodoItem(title: "Read Swift docs", priority: 1))
    }
}

#endif
