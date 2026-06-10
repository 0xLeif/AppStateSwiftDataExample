# AppState · SwiftData Example

🗃️ A SwiftData demo for [AppState](https://github.com/0xLeif/AppState) 3.0.0 — showing how to back a
SwiftUI app with `ModelState`, a shared `ModelContainer` dependency, and a background `@ModelActor`.

> Requires AppState 3.0.0+ (SwiftData support). Until 3.0.0 ships, the package tracks the AppState
> `develop` branch.

## What it shows

- **`ModelState` / `@ModelState`** — read and mutate SwiftData models through AppState's scope.
- **A `ModelContainer` dependency** — one shared container, injected like any other AppState dependency.
- **Relationships + cascade** — `TodoList → cascade → TodoItem`, `TodoItem ↔ nullify ↔ Tag`.
- **Complex queries** — compound `#Predicate`, multi-key sort, `fetchLimit`.
- **Unique constraints** — `@Attribute(.unique)` upsert behavior.
- **Schema migration** — a `VersionedSchema` V1 → V2 with a `SchemaMigrationPlan`.
- **Non-blocking bulk work** — a background `@ModelActor` imports thousands of models off the main
  thread, with live progress and cancellation, while the UI stays responsive.

## Structure

```
.                       SwiftPM package — the example library + a console executable + tests
├── Sources/
│   ├── SwiftDataExampleLib/   models, schema/migration, stores, @ModelActor, SwiftUI views
│   └── SwiftDataExample/      @main console walkthrough
├── Tests/
└── DemoApp/            xcodegen iOS app that runs the SwiftUI screens
```

## Run it

**Tests / console walkthrough**

```sh
swift test
swift run
```

**The iOS demo app** (needs [XcodeGen](https://github.com/yonaskolb/XcodeGen))

```sh
cd DemoApp
xcodegen generate
open AppStateSwiftDataDemo.xcodeproj   # then Run
```

The catalog has two screens: **SwiftData Lab** (create lists, tag items, run the live filter,
cascade-delete) and **Bulk Import** (generate 10k items off-main and watch the UI stay smooth).
