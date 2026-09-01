# Observation: Granularity and Lifecycle

Two traps of the `Observation` framework that aren't apparent when reading the documentation and that decide how you model a store.

---

## 1. Granularity Is Lost When State Is Nested in a Struct

`@Observable` tracks accesses **by stored property**. If all state lives inside a single struct, changing any field invalidates every view that reads *any* other field—and you are back to the Redux-style re-rendering problem, where a central state blob redraws unrelated views.

**Verified with `withObservationTracking`** (Swift 6.2, macOS 15.7):

```swift
struct NestedState { var a = 0; var b = 0 }

@Observable final class Flat   { var a = 0; var b = 0 }
@Observable final class Nested { var state = NestedState() }
```

| Case | Reads | Changes | Invalidates? |
|---|---|---|---|
| Flat | `flat.a` | `flat.b` | **no** |
| Nested | `nested.state.a` | `nested.state.b` | **yes** |

```swift
// Wrong — blob: any change repaints everything that reads the store.
@Observable final class NoteStore {
    struct State { var notes: [Note] = []; var query = ""; var isLoading = false }
    var state = State()
}

// Right — flat properties: each view only invalidates what it reads.
@Observable final class NoteStore {
    private(set) var notes: [Note] = []
    var query = ""
    private(set) var isLoading = false
}
```

**Rule**: Observable properties should be flat in the class. Group in structs only what truly changes together and is consumed together.

Corollary: Do not bring the `StateContainer<State>` from unidirectional architectures into `@Observable`. That form existed because `ObservableObject` with `@Published` lacked granularity; with `Observation` you have it by default, and wrapping the state removes it.

---

## 2. Do not rely on `init` / `deinit`

In SwiftUI **you do not control view lifecycles**: the framework creates and destroys view descriptions whenever it chooses and may evaluate them several times. `@StateObject` (iOS 14) restored some control over when a state object is created and destroyed, but **the `@Observable` macro broke that guarantee again**.

**Practical consequence**: any pattern that depends on `init` and `deinit` is fragile.

```swift
// Wrong — fragile: the subscription is created and cancelled when the framework decides.
@Observable final class NoteStore {
    private var watcher: FSEventStreamRef?
    init() { watcher = startWatching() }
    deinit { stopWatching(watcher) }      // When? You do not know.
}
```

```swift
// Right — explicit: the lifecycle is set by the view, which does expose it.
struct NoteListScreen: View {
    @Environment(NoteStore.self) private var store

    var body: some View {
        NoteListView(notes: store.notes) { … }
            .task { await store.startWatching() }   // Cancels when the view disappears
    }
}
```

`.task` is preferable to `onAppear`/`onDisappear` for asynchronous work: SwiftUI cancels the task when the view disappears, so you do not have to remember to cancel it.

**Exception**: a store injected into the root with `@State` in the `App` lives as long as the app. There, `init` is deterministic. The trap is in objects created by intermediate views.

---

## 3. Where to place an event enum (and where not)

This skill recommends [grouping the events of a component in an enum](architecture.md#events-grouped-in-an-enum). That **is not** the same as modeling the entire app flow as events, in the style of Redux/TCA.

| | Event enum of a view | App‑wide events |
|---|---|---|
| Scope | Outputs of **one** component | Entire control flow |
| Where resolved | Immediate parent, adjacent `switch` | Central reducer, far away |
| Cost | None | The “ping‑pong” problem |

The ping-pong problem: modeling actions as values splits a flow that should read from top to bottom into N cases that call one another.

```swift
// Split flow: you have to jump between cases to understand it.
func handle(event: Event) {
    switch event {
    case .onAppear:
        state = .loading
        return .task { await send(.numbersDownloaded(try await api.numbers())) }
    case .numbersDownloaded(let values):
        state = .loaded(values)
        return .none
    }
}

// Cohesive and readable in one go.
func onAppear() async {
    state = .loading
    state = .loaded(try await api.numbers())
}
```

Use the enum to **cross a component boundary**. Do not use it to express asynchronous sequences.

---

## Sources

- [SwiftUI Observation Framework: State Containers](https://medium.com/the-swift-cooperative/swiftui-observation-framework-state-containers-56133d8a8751) — Luis Recuenco
- [SwiftUI View Models: Lifecycle Quirks](https://medium.com/the-swift-cooperative/swiftui-view-models-lifecycle-quirks-8dd967e84e31) — Luis Recuenco
- [The Dark Side of Unidirectional Architectures in Swift](https://medium.com/the-swift-cooperative/the-dark-side-of-unidirectional-architectures-in-swift-e4acf243ff1c) — Luis Recuenco
