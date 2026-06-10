import AppState
import SwiftUI

#if canImport(SwiftData)
import SwiftData
import SwiftDataExampleLib
#endif

// MARK: - App entry point

/// A host app that runs the SwiftData + AppState examples on a device or simulator.
///
/// Every screen is a *public* root view shipped by `SwiftDataExampleLib`. The catalog provides the
/// single `NavigationStack` and injects the shared `\.labContainer` into the environment, so both the
/// AppState `@ModelState` examples and the native SwiftData `@Query` example read the same store.
@main
struct AppStateSwiftDataDemoApp: App {
    var body: some Scene {
        WindowGroup {
            #if canImport(SwiftData)
            ExampleCatalogView()
                .modelContainer(Application.dependency(\.labContainer))
            #else
            Text("SwiftData is unavailable on this platform.")
            #endif
        }
    }
}

// MARK: - Catalog

#if canImport(SwiftData)
@available(iOS 18.0, *)
struct ExampleCatalogView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Data") {
                    row("Seed & Stress", "shippingbox.fill", "fill the store with a TON of related data, off-main") {
                        SeederView()
                    }
                }

                Section("Core") {
                    row("SwiftData Lab", "tablecells", "relationships, cascade, queries, migration") {
                        SwiftDataLabView()
                    }
                    row("Bulk Import", "bolt.fill", "10k items off-main on a background @ModelActor") {
                        BulkImportView()
                    }
                }

                Section("Reading data") {
                    row("Live @Query", "bolt.horizontal", "native SwiftData @Query, auto-updating") {
                        QueryLiveListView()
                    }
                    row("Search", "magnifyingglass", "#Predicate text search, live") {
                        ItemSearchView()
                    }
                    row("Sort & Filter", "arrow.up.arrow.down", "rebuild a FetchDescriptor live") {
                        SortFilterView()
                    }
                    row("Stats", "chart.bar.fill", "aggregations derived from @ModelState") {
                        StatsView()
                    }
                }

                Section("Writing data") {
                    row("Edit", "pencil", "edit a @Model live and persist") {
                        ItemEditorView()
                    }
                    row("Undo / Redo", "arrow.uturn.backward", "the ModelContext undo manager") {
                        UndoRedoView()
                    }
                }
            }
            .navigationTitle("AppState · SwiftData")
            .task {
                // Populate the store on a fresh launch so every screen has data to show. The seed
                // runs on a background @ModelActor and no-ops if the store is already populated.
                await seedSampleDataIfEmpty()
            }
        }
    }

    private func row<Destination: View>(
        _ title: String,
        _ systemImage: String,
        _ subtitle: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}
#endif
