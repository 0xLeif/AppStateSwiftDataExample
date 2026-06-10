import SwiftUI

#if canImport(SwiftData)
import SwiftDataExampleLib
#endif

// MARK: - App entry point

/// A host app that runs the SwiftData + AppState examples on a device or simulator.
///
/// Each row drives into a *public* root view shipped by the `SwiftDataExampleLib` package, so what
/// you see here is exactly the SwiftUI the example library exposes and tests.
@main
struct AppStateSwiftDataDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ExampleCatalogView()
        }
    }
}

// MARK: - Catalog

@available(iOS 18.0, *)
struct ExampleCatalogView: View {
    var body: some View {
        NavigationStack {
            List {
                #if canImport(SwiftData)
                Section {
                    NavigationLink("SwiftData Lab — relationships, queries, migration") {
                        SwiftDataLabView()
                    }
                    NavigationLink("Bulk Import — 10k items off-main, responsive") {
                        BulkImportView()
                    }
                } header: {
                    Text("SwiftData + AppState")
                } footer: {
                    Text("ModelState, a ModelContainer dependency, and a background @ModelActor that imports thousands of models without blocking the UI.")
                }
                #else
                Text("SwiftData is unavailable on this platform.")
                #endif
            }
            .navigationTitle("AppState · SwiftData")
        }
    }
}
