import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - UndoRedoView

/// Demonstrates SwiftData undo/redo by driving the `ModelContext`'s `undoManager` directly.
///
/// SwiftData's `ModelContext` exposes an optional `undoManager` that, when set, records every
/// insert/delete mutation as an undoable action. This view ensures that manager exists on appear,
/// then lets the user add and delete `TodoItem`s and step backwards and forwards through the
/// history using standard `UndoManager` calls.
///
/// ### Why assign the undoManager manually?
/// A `ModelContext` created by a `ModelContainer` does not automatically attach an
/// `UndoManager`; you must assign one yourself (or use `SwiftUI.Environment`'s
/// `\.undoManager` when that is appropriate). Assigning a fresh `UndoManager()` is the
/// simplest cross-platform approach that works in both app and test targets.
///
/// ```swift
/// // In a host SwiftUI app:
/// UndoRedoView()
/// ```
@MainActor
public struct UndoRedoView: View {

    // MARK: - Properties

    /// Counter that forces a body re-evaluation after each mutation so the list stays live.
    @State private var refreshToken: Int = 0

    /// Item count cached from `allItems` after each mutation; drives the live row list.
    @State private var items: [TodoItem] = []

    /// Whether the undo manager currently has actions available to undo.
    @State private var canUndo: Bool = false

    /// Whether the undo manager currently has actions available to redo.
    @State private var canRedo: Bool = false

    // MARK: - Initialiser

    /// Creates an `UndoRedoView`.
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

    /// A brief explanatory banner describing how the ModelContext undo manager works.
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

    /// Ensures the container's `mainContext` has a non-nil `undoManager`.
    ///
    /// SwiftData does not auto-assign an `UndoManager` to a freshly created context.
    /// We assign one here if absent so that subsequent insert/delete calls are tracked.
    private func ensureUndoManagerAttached() {
        let context = Application.dependency(\.labContainer).mainContext
        if context.undoManager == nil {
            context.undoManager = UndoManager()
        }
        syncUndoState()
    }

    /// Inserts a new `TodoItem` with an auto-generated title and saves the context.
    private func addItem() {
        let context = Application.dependency(\.labContainer).mainContext
        let item = TodoItem(title: "Item \(items.count + 1)")
        context.insert(item)
        try? context.save()
        refreshItems()
        syncUndoState()
    }

    /// Deletes the last item (by title sort) from the context and saves.
    private func deleteLast() {
        guard let last = items.last else { return }
        let context = Application.dependency(\.labContainer).mainContext
        context.delete(last)
        try? context.save()
        refreshItems()
        syncUndoState()
    }

    /// Calls `UndoManager.undo()` on the context's manager, then refreshes the displayed state.
    private func performUndo() {
        let context = Application.dependency(\.labContainer).mainContext
        context.undoManager?.undo()
        refreshItems()
        syncUndoState()
    }

    /// Calls `UndoManager.redo()` on the context's manager, then refreshes the displayed state.
    private func performRedo() {
        let context = Application.dependency(\.labContainer).mainContext
        context.undoManager?.redo()
        refreshItems()
        syncUndoState()
    }

    // MARK: - Private Helpers

    /// Re-fetches items from the context so the list reflects the current persisted state.
    private func refreshItems() {
        let context = Application.dependency(\.labContainer).mainContext
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [SortDescriptor(\.title)]
        )
        items = (try? context.fetch(descriptor)) ?? []
    }

    /// Reads `canUndo` / `canRedo` from the undo manager and updates the matching state vars.
    private func syncUndoState() {
        let manager = Application.dependency(\.labContainer).mainContext.undoManager
        canUndo = manager?.canUndo ?? false
        canRedo = manager?.canRedo ?? false
    }
}

// MARK: - UndoRedoItemRow

/// A compact row that displays a single `TodoItem`'s title and creation date.
public struct UndoRedoItemRow: View {

    // MARK: Properties

    /// The item to display.
    public let item: TodoItem

    // MARK: Initialiser

    /// Creates an `UndoRedoItemRow` for the given item.
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
