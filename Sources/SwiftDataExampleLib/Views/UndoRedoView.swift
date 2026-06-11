import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - UndoRedoView

/// Demonstrates `ModelContext` undo/redo by wiring a fresh `UndoManager()` on appear.
///
/// A `ModelContext` doesn't auto-attach an `UndoManager` — you must assign one yourself.
///
/// ```swift
/// UndoRedoView()
/// ```
@MainActor
public struct UndoRedoView: View {

    // MARK: - Properties

    @State private var refreshToken: Int = 0
    @State private var items: [TodoItem] = []
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            captionSection
            buttonSection
            itemListSection
        }
        .navigationTitle("Undo / Redo")
        .onAppear {
            ensureUndoManagerAttached()
            refreshItems()
        }
    }

    // MARK: - Sub-views

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ModelContext Undo Manager")
                .font(.headline)
            Text(
                "Each insert and delete is recorded by the context's UndoManager. " +
                "Tap \"Undo\" to reverse the last change and \"Redo\" to reapply it. " +
                "The list below updates immediately so you can watch rows appear and disappear."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .padding([.horizontal, .top])
    }

    private var buttonSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                addItemButton
                deleteLastButton
            }
            HStack(spacing: 12) {
                undoButton
                redoButton
            }
        }
        .padding()
    }

    private var addItemButton: some View {
        Button(action: addItem) {
            Label("Add Item", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("undoRedo.addItem")
    }

    private var deleteLastButton: some View {
        Button(action: deleteLast) {
            Label("Delete Last", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(items.isEmpty)
        .accessibilityIdentifier("undoRedo.deleteLast")
    }

    private var undoButton: some View {
        Button(action: performUndo) {
            Label("Undo", systemImage: "arrow.uturn.backward")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!canUndo)
        .accessibilityIdentifier("undoRedo.undo")
    }

    private var redoButton: some View {
        Button(action: performRedo) {
            Label("Redo", systemImage: "arrow.uturn.forward")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!canRedo)
        .accessibilityIdentifier("undoRedo.redo")
    }

    private var itemListSection: some View {
        List {
            Section("Items (\(items.count))") {
                if items.isEmpty {
                    Text("No items yet — tap \"Add Item\" to begin.")
                        .foregroundStyle(.secondary)
                        .italic()
                        .accessibilityIdentifier("undoRedo.emptyPlaceholder")
                } else {
                    ForEach(items, id: \.persistentModelID) { item in
                        UndoRedoItemRow(item: item)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func ensureUndoManagerAttached() {
        let context = Application.dependency(\.labContainer).mainContext
        if context.undoManager == nil {
            context.undoManager = UndoManager()
        }
        syncUndoState()
    }

    private func addItem() {
        let context = Application.dependency(\.labContainer).mainContext
        let item = TodoItem(title: "Item \(items.count + 1)")
        context.insert(item)
        try? context.save()
        refreshItems()
        syncUndoState()
    }

    private func deleteLast() {
        guard let last = items.last else { return }
        let context = Application.dependency(\.labContainer).mainContext
        context.delete(last)
        try? context.save()
        refreshItems()
        syncUndoState()
    }

    private func performUndo() {
        let context = Application.dependency(\.labContainer).mainContext
        context.undoManager?.undo()
        refreshItems()
        syncUndoState()
    }

    private func performRedo() {
        let context = Application.dependency(\.labContainer).mainContext
        context.undoManager?.redo()
        refreshItems()
        syncUndoState()
    }

    // MARK: - Private Helpers

    private func refreshItems() {
        let context = Application.dependency(\.labContainer).mainContext
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [SortDescriptor(\.title)]
        )
        items = (try? context.fetch(descriptor)) ?? []
    }

    private func syncUndoState() {
        let manager = Application.dependency(\.labContainer).mainContext.undoManager
        canUndo = manager?.canUndo ?? false
        canRedo = manager?.canRedo ?? false
    }
}

// MARK: - UndoRedoItemRow

/// Row: title and creation time.
public struct UndoRedoItemRow: View {

    public let item: TodoItem

    public init(item: TodoItem) {
        self.item = item
    }

    // MARK: Body

    public var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                Text(item.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#endif
