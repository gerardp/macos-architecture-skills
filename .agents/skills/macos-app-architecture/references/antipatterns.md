# Anti-Patterns

What **not** to do, with the wrong code side by side with the right. If
something here looks like a good idea, read the rationale before reopening it.

---

## ❌ MVVM: One ViewModel per Screen

The SwiftUI view is already the presentation layer. One ViewModel per screen
duplicates that layer and creates three problems.

**The bad code:**

```swift
@Observable
class NoteListViewModel {
    var notes: [Note] = []
    let repository: NoteRepository
    init(repository: NoteRepository) { self.repository = repository }
    func load() async throws { notes = try await repository.loadAll() }
}

@Observable
class AddNoteViewModel {
    let repository: NoteRepository          // same dependency again
    var title = ""
    var isFormValid: Bool { !title.isEmpty }
    func save() async throws -> Note { … }
}

struct NoteListScreen: View {
    let vm: NoteListViewModel
    @State private var isPresented = false

    var body: some View {
        List(vm.notes) { Text($0.title) }
            .sheet(isPresented: $isPresented) {
                // You have to wire dependencies by hand and return the
                // result through a closure so the list receives the update.
                AddNoteScreen(vm: AddNoteViewModel(repository: vm.repository)) { note in
                    vm.notes.append(note)
                }
            }
    }
}
```

**The three costs:**

1. **N screens ⇒ N view models**, and with them the problem of how to
   communicate. With 30 screens, it becomes difficult to identify the source of truth.
2. **The `Environment` isn’t reachable from a view model** — it’s a view API.
   The usual workaround (putting VMs in the `Environment`) contradicts the
   MVVM premise that a VM is bound to a screen.
3. When the view doesn’t refresh, flags and toggles appear to force updates.
   They’re not solutions; they’re fighting the framework.

**The good code:** a store per bounded context in the `Environment`, and
presentation logic in the view.

```swift
struct NoteListScreen: View {
    @Environment(NoteStore.self) private var store
    @State private var isPresented = false

    var body: some View {
        List(store.notes) { Text($0.title) }
            .sheet(isPresented: $isPresented) { AddNoteScreen() }
            .task { try? await store.load() }
    }
}

struct AddNoteScreen: View {
    @Environment(NoteStore.self) private var store   // same store, no wiring
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""

    private var isFormValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form { TextField("Title", text: $title) }
            .toolbar {
                Button("Save") {
                    Task { try await store.add(title: title); dismiss() }
                }
                .disabled(!isFormValid)
            }
    }
}
```

No need to return anything by closure: both screens read from the same store,
so the list updates itself.

See [architecture.md](architecture.md#bounded-context-stores).

### Exception: Complex, Observable, Local View State

The rule is **do not create one ViewModel per screen or by default**. It is not
“no class may ever hold view state”.

There is a case where a private, local-to-a-screen, observable class is the
right answer: when the view’s logic (a) has its own mutable state, (b) needs
to be observable, and (c) is too large to live in the `body`.

```swift
struct ExpenseSummaryScreen: View {
    // Private, local to this screen, NOT in the Environment.
    @Observable private final class Model {
        var range: SummaryRange = .year
        private let store: TransactionStore

        init(store: TransactionStore) { self.store = store }

        var expenses: [Transaction] {
            store.transactions(since: range.startDate)
                .filter { $0.type == .expense }
                .sorted(using: KeyPathComparator(\.date))
        }
        var total: Decimal { expenses.map(\.amount).reduce(0, +) }
    }

    @State private var model: Model
    var body: some View { … }
}
```

**The three conditions that make it legitimate**, separating it from MVVM:

1. **It’s `private` and local to a screen.** It never enters the `Environment`
   nor is shared with anyone else.
2. **It’s not created per screen system-wide.** It appears only where the
   logic justifies it; most screens don’t need it.
3. **It doesn’t duplicate the store.** It derives from it and adds
   *presentation state*.

**And the reason why this should *not* go into the store:** that logic is
specific to a single view. Pushing it into a shared store to make it testable
turns it into a **god object**, which is a worse disease than the one we’re
trying to cure. The rule still holds — *if two features share it, it doesn’t
belong to either* — read it backwards: **if only one view uses it, it doesn’t
belong to the store**.

When to prefer each option:

| Situation | What to use |
|---|---|
| Simple derivation without state | Computed property in the view |
| Stateless logic worth testing | Extracted value type ([validation](validation.md#4-extract-the-form-into-a-type-the-important-pattern)) |
| Complex, observable, presentation‑state, single‑screen | Private `@Observable` class |
| Shared domain state | Store per bounded context |

**Critique that sparked this entry:**
[The SwiftUI MV Pattern Is an Anti‑Pattern](https://matteomanferdini.com/swiftui-mv-pattern/),
Matteo Manferdini. His general thesis—that MV is an anti-pattern—does not hold:
exceptions do not invalidate a pattern, and his main argument is genetic (that
MV descends from MVC says nothing about its usefulness). But **he was right
about this specific case, which was missing here**.

### Exception: Bridging a KVO/Combine API

There is a case where `ObservableObject` with `@Published` **is the right
choice**, while `@Observable` does not work: wrapping a third-party API based on
KVO whose state arrives via a Combine publisher. Sparkle is the canonical
example, and it appears in its documentation and the `axiom-macos`
skill `direct-distribution.md`:

```swift
import Sparkle

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private let updater: SPUUpdater

    init(controller: SPUStandardUpdaterController) {
        self.updater = controller.updater
        // `.assign(to: &$…)` requires @Published. With @Observable there’s
        // no such bridge: you’d have to rewrite it with a manual observer.
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() { updater.checkForUpdates() }
}
```

**Do not “modernize” it to `@Observable`**: that would break the bridge for no
benefit. It adapts an external API; it is not a presentation layer, and it is
named `…ViewModel` only because Sparkle uses that name. The rule against view
models is about *not duplicating the presentation layer*, not prohibiting a
class that adapts KVO.

---

## ❌ Giant Views (the “massive view controller” by another name)

In UIKit the endemic problem was *massive view controllers*. SwiftUI removed
the view controllers, but **the code that lived inside didn’t disappear**; it
moved into the views. SwiftUI eliminated boilerplate, not responsibilities.

That’s the real risk of taking the MV pattern lightly: without view models,
everything tends toward the `body`.

```swift
// ❌ Everything inside: formatting, domain logic, layout, and state.
struct BudgetScreen: View {
    @Environment(TransactionStore.self) private var store
    @State private var range: SummaryRange = .year

    var body: some View {
        List {
            // Embedded formatting
            Text("Balance")
            Text({
                let f = NumberFormatter(); f.numberStyle = .currency
                return f.string(from: NSNumber(value: Float(store.balance) / 100)) ?? ""
            }())

            // Embedded domain logic
            ForEach(store.transactions
                .filter { $0.date > range.startDate && $0.type == .expense }
                .sorted { $0.date > $1.date }) { transaction in

                // Embedded row layout
                HStack(spacing: 16) {
                    Image(systemName: transaction.category.symbol)
                        .foregroundStyle(transaction.category.color)
                    VStack(alignment: .leading) {
                        Text(transaction.title)
                        Text({
                            let f = DateFormatter(); f.dateStyle = .medium
                            return f.string(from: transaction.date)
                        }())
                    }
                    Spacer()
                    Text("\(transaction.amount)")
                }
            }
        }
    }
}
```

Three concerns are mixed together, and none can be tested or previewed
separately. Separate them as follows:

```swift
// ✅ 1. Formatting, reusable and testable extensions.
//    (verified: compiles; output varies with the current locale)
extension Int {
    /// Cents → localized currency text.
    var currencyFormat: String {
        (Decimal(self) / 100).formatted(
            .currency(code: Locale.current.currency?.identifier ?? "EUR")
        )
    }
}

extension Date {
    var transactionFormat: String { formatted(date: .abbreviated, time: .omitted) }
}

// ✅ 2. Domain logic, a testable value type.
struct ExpenseQuery {
    var range: SummaryRange

    func apply(to transactions: [Transaction]) -> [Transaction] {
        transactions
            .filter { $0.date > range.startDate && $0.type == .expense }
            .sorted { $0.date > $1.date }
    }
}

// ✅ 3. Layout, moved into presentation components that can be previewed separately.
struct BalanceView: View {
    let amount: Int
    var body: some View {
        VStack(alignment: .leading) {
            Text("Balance").font(.callout).bold().foregroundStyle(.secondary)
            Text(amount.currencyFormat).font(.largeTitle).bold()
        }
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    var body: some View { … }
}

// ✅ The screen becomes what it should be: composition.
struct BudgetScreen: View {
    @Environment(TransactionStore.self) private var store
    @State private var query = ExpenseQuery(range: .year)

    var body: some View {
        List {
            BalanceView(amount: store.balance)
            ForEach(query.apply(to: store.transactions)) { TransactionRowView(transaction: $0) }
        }
    }
}
```

The test that proves you’ve separated it correctly is: **Can you preview
`BalanceView` and `TransactionRowView` separately, and test `ExpenseQuery`
without a UI?** See [previews.md](previews.md).

---

## ❌ Storing What Can Be Derived

```swift
// BAD: two sources of truth that must be kept in sync manually.
@State private var notes: [Note] = []
@State private var filteredNotes: [Note] = []

private func applyFilter() {
    filteredNotes = notes.filter { $0.title.contains(query) }
}
// …and you’ll forget to call applyFilter() wherever `notes` or `query` change.
```

```swift
// GOOD: derive. Impossible to get out of sync.
@State private var query = ""

private var visibleNotes: [Note] {
    store.notes.filter { query.isEmpty || $0.title.localizedStandardContains(query) }
}
```

If the calculation becomes expensive, profile it with Instruments before
caching.

### Important Nuance: Derive Data, Not Views

This rule concerns **deriving data**, not splitting a long `body` into
computed properties that return `some View`:

```swift
// ✅ Derive DATA: correct, impossible to get out of sync.
private var visibleNotes: [Note] { store.notes.filter { … } }

// ❌ Split VIEWS: false economy. The body looks clean,
//    but nothing has been decoupled.
private var header: some View { VStack { … } }
private var footer: some View { HStack { … } }
```

The latter hides complexity instead of separating it, and costs three
concrete things:

1. **You can’t preview** that UI piece separately.
2. **You can’t reuse** it in another screen; you’d have to copy‑paste.
3. **It hinders the diffing engine**: a property has no identity of its own, so
   it is re-evaluated with its parent. A separate `struct View` may skip the
   redraw when its inputs have not changed.

If a piece of `body` deserves a name, it deserves to be a `View`. See
[view-composition.md](view-composition.md).

---

## ❌ An Enum for All View State

Very common pattern, and recommended in many guides — including
[SwiftUI in 2025: Forget MVVM](https://dimillian.medium.com/swiftui-in-2025-forget-mvvm-262ff2bbd2ed),
Thomas Ricouard, whose case against ViewModels this file otherwise shares:

```swift
// ❌ Sum type: only one case can be true at a time.
enum ViewState {
    case loading
    case loaded([Note])
    case error(String)
}

struct NoteListScreen: View {
    @State private var state: ViewState = .loading

    var body: some View {
        switch state {
        case .loading:          ProgressView()
        case .loaded(let notes): NoteListView(notes: notes)
        case .error(let message): ErrorView(message: message)
        }
    }
}
```

**Where this breaks—and it always does—is reloading.** You want to keep showing
the notes you already had **and** report the error. Because the enum is a sum
type, it cannot be `.loaded` and `.error` at the same time, so patching begins:

```swift
case error(String, [Note]?)     // ← now .loading also needs the array
case loading([Note]?)           // ← now the switch explodes with combined cases
```

Every overlapping state multiplies the cases. It’s the symptom of using a sum
type where a product type was needed.

```swift
// ✅ Struct: states can overlap without breaking.
struct NoteListState {
    var notes: [Note] = []
    var isLoading = false
    var lastError: String?
}

struct NoteListScreen: View {
    @State private var state = NoteListState()

    var body: some View {
        NoteListView(notes: state.notes)          // always the latest data available
            .overlay { if state.isLoading { ProgressView() } }
            .alert("Error", isPresented: Binding(
                get: { state.lastError != nil },
                set: { if !$0 { state.lastError = nil } }
            )) {
                Button("OK") { state.lastError = nil }
            } message: {
                Text(state.lastError ?? "")
            }
    }
}
```

**When the enum is appropriate:** when the states are truly exclusive and
never overlap—like a modal edit state, a document type, or a currently active
tab. If you ever need to be in two cases simultaneously, it wasn’t the right
sum type.

> **This does not contradict [events grouped in an enum](architecture.md#events-grouped-in-an-enum).**
> They’re different concepts:
>
> | | **Event** enum | **State** enum |
> |---|---|---|
> | Models | Something that **happened**, once | Something that **is**, continuously |
> | Do they overlap? | No: an event is one | Yes, almost always: loading *with* old notes |
> | Lifetime | Instantaneous; consumed and gone | Persists between redraws |
> | Verdict | ✅ Use it | ⚠️ Only when the states are truly exclusive |
>
> An event is inherently momentary, so a sum type fits perfectly. State lasts,
> and long-lived states tend to overlap.

---

## ❌ Letting a Reusable Component Read from the `Environment`

```swift
// BAD: NoteRowView is no longer reusable. It carries an invisible contract
// and will break in any context where `NoteStore` doesn’t exist, including
// previews.
struct NoteRowView: View {
    @Environment(NoteStore.self) private var store
    let noteID: Note.ID
    var body: some View { Text(store.notes.first { $0.id == noteID }?.title ?? "") }
}
```

```swift
// GOOD: receives what it needs, emits events. It can be previewed and reused
// anywhere.
struct NoteRowView: View {
    let note: Note
    let onEvent: (NoteRowEvent) -> Void
    var body: some View { Text(note.title) }
}
```

**Rule:** `…Screen`s read from the `Environment`; `…View`s do not.

---

## ❌ N Closures Instead of an Event Enum

See the full example in
[architecture.md](architecture.md#events-grouped-in-an-enum). In short: with
separate closures, adding an event breaks nothing and one call site can be
forgotten; with an enum, the `switch` stops compiling and the compiler leads
you to every consumer.

---

## ❌ Routing High-Frequency Events Through SwiftUI

Scroll, drag, cursor movement are per‑frame signals. Passing them through the
SwiftUI update cycle—binding them to an `@Binding` or mutating an
`@Observable` in every event—**won’t give you 60 fps**: each change invalidates
the `body` and triggers a diff that you don’t need.

```swift
// ❌ Every pixel of scroll invalidates the parent view’s body.
@Observable final class ScrollState { var offset: CGFloat = 0 }
```

```swift
// ✅ Direct imperative path between the two views, and observable state
//    only for what the declarative UI actually paints.
final class ScrollBridge {                     // not @Observable
    var onScroll: ((CGFloat) -> Void)?
}
```

Observable state is for what gets rendered, not for high-frequency synchronization.

---

## ❌ Putting a Database Under a File-Based Model

If the source of truth is a set of files that users can edit outside the app
(through iCloud, Dropbox, or another editor), putting Core Data or SwiftData in
front creates a **second source of
truth** that must be reconciled on every launch and every external change.

A SQLite/FTS5 index is fine as a **derived, disposable cache**, but never as the
source of truth—and only after measurements show that it is needed.

---

## ❌ Assuming iOS Material Applies to macOS

Repeatedly verified: UIKit material doesn’t apply to macOS; SwiftUI
performance audits don’t touch TextKit or WebKit; release guides assume Xcode
projects. Before adopting any material, run `grep` for `AppKit`, `NSView`, and
`macOS`. If you get nothing, it doesn’t apply.

---

## Sources

- [MVVM and the Cost of Carrying Old Patterns Forward](https://azamsharp.com/2026/03/04/mvvm-and-cost-of-old-patterns.html)
- [Building Large-Scale Apps with SwiftUI](https://azamsharp.com/2023/02/28/building-large-scale-apps-swiftui.html)
- [SwiftUI in 2025: Forget MVVM](https://dimillian.medium.com/swiftui-in-2025-forget-mvvm-262ff2bbd2ed),
  Thomas Ricouard — the same conclusion reached from production apps (IcySky,
  the Medium iOS app) rather than from first principles. Agrees on everything
  here except the view-state enum above.
