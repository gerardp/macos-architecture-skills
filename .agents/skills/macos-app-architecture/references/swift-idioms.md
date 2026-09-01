# Swift Idioms That Shape the Architecture

> **Scope.** The `write-swift` skill is the reference for the language itself —
> value semantics and copy-on-write, `~Copyable` and ownership, `some` vs `any`,
> `@concurrent` and the Swift 6.2 concurrency model, performance and ARC. The
> official [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
> are the reference for **naming**. Neither is duplicated here.
>
> This document keeps only what those do not cover: the language decisions that
> shape an app's **structure**, and the conventions this skill imposes.

Three ideas from the official guide concern design rather than style:

- **Clarity at the point of use is the primary goal.** A type is declared once and used many times; evaluate the name by reading the call, not the declaration.
- **Clarity before brevity.**
- **If you have trouble describing an API in simple terms, the API is likely poorly designed.** It is the best detector of a bad design, and it is free.

---

## Value Types and `final`: Pointers Only

The rules themselves live in `write-swift` (§1): default to `struct`/`enum`,
copy-on-write via `isKnownUniquelyReferenced`, `~Copyable` for unique ownership,
`borrowing`/`consuming`. Two consequences matter for this architecture and are
easy to miss:

- **`@Observable` types are classes by necessity.** Observation needs reference
  identity, so "prefer structs" does not apply to stores. Not a compromise — a
  requirement.
- **Why protocols instead of inheritance**, in one concrete sentence: a
  superclass meant only to be subclassed **can still be instantiated**, and the
  compiler will not stop you — Swift has no abstract classes. Those meaningless
  instances leak into the code and nobody notices until they fail. A protocol
  cannot be instantiated: the compiler backs you instead of leaving you with a
  convention.

## Existentials at the Framework Boundary

`write-swift` (§7) covers `some` vs `any` and why generics are preferred. The
app-level caveat it cannot give you: **SwiftUI forces existentials in specific
places**, and that is not a failure of discipline.

- `EnvironmentValues` needs a concrete type; you cannot parameterise it per view,
  so a service stored there is `any Service`.
- Heterogeneous collections: `[any Renderer]`.

Conversely, `@Environment(_:)` and `@Bindable` **reject** existentials and demand
the concrete `@Observable` type — verified in
[architecture.md](architecture.md#shared-state--environment). That pair of
constraints is what places the abstraction seam below the store, not at it.

The cost of one box per access is irrelevant next to drawing a view; it stops
being irrelevant inside a layout loop.

## Closure or Protocol

Both serve to decouple. The deciding criteria:

| | Closure | Protocol |
|---|---|---|
| Size | A single operation | A role with multiple operations |
| Retained state | Can capture it | Stored by the conforming type |
| Indirection | None | **One extra layer** |
| Test replaceability | By passing another closure | By another conformance |

**One operation ⇒ closure.** This is how
[view events](architecture.md#events-grouped-in-an-enum) work: `onEvent` is a
closure, not a `NoteRowViewDelegate`.

**A role with multiple operations and state ⇒ protocol.** That is what `NoteRepository` does: loading, saving, deleting, and observing are a role, not four loose closures.

The cost of a protocol is **one extra layer of indirection**. Used well, it
enables reuse; multiplied indiscriminately, it creates an abstraction maze in
which following one call requires opening five files.

## `.task` vs `Task { }` in SwiftUI

`write-swift` (§3, §5) covers structured concurrency and states the rule: use
`Task { }` only when the work's lifetime does not fit a scope — a button tap, a
delegate callback — and manage cancellation yourself.

What it does not cover, because it is a SwiftUI API rather than a language one:
**`.task` manages that cancellation for you.**

```swift
// Tied to the view's lifetime — SwiftUI cancels it on disappear.
.task { await store.startWatching() }
.task(id: selectedNoteID) { await load() }   // re-cancelled when the id changes

// Correct, and the only option inside a synchronous action closure —
//    but it is NOT cancelled when the view goes away.
Button("Save") { Task { try await store.save(note) } }
```

The decision: **`.task` for work bound to the view; `Task { }` only for actions
that must finish even if the user navigates away** — saving, deleting. And in
that case the work belongs in the store, not in the view.

`DispatchQueue.main.async` has no place in new code: that is `@MainActor`.

## One Type per File, with Exceptions for Extensions

A `struct`, `class`, or `enum` per file, with the type name. **Extensions are the accepted exception**: `Note+Markdown.swift` with extensions on an already defined type is correct, as is grouping several small conformances for the same type.

Small `private` helpers used only by that file are also exempt.

```
Features/Editor/
├── NoteEditorScreen.swift        // struct NoteEditorScreen
├── SourceEditorView.swift        // struct SourceEditorView + its private Coordinator
└── Note+Editing.swift            // extensions on Note: OK, not another type

Model/
├── Note.swift                    // struct Note
└── Note+Codable.swift            // separate conformance: OK
```

A private `Coordinator` inside its `NSViewRepresentable` file is appropriate:
it does not exist outside that file. Putting `Note`, `Tag`, and `Notebook` into
one `Models.swift` file is not.

---

## Enums: Exhaustiveness and Evolution

Within an app, enums are exhaustive, which is an advantage: adding a case breaks
compilation in every `switch` that consumes it. This is precisely the argument
for [grouped events](architecture.md#events-grouped-in-an-enum).

**A public API consumed by others is different**: adding a case breaks client
code. The idiomatic pattern is an internal enum wrapped in a public struct whose
`static let` properties mimic enum-case syntax:

```swift
public struct NoteKind: Sendable, Equatable {
    private enum Storage { case note, template, attachment }
    private let storage: Storage

    public static let note = NoteKind(storage: .note)
    public static let template = NoteKind(storage: .template)
}
```

It is used the same way (`.note`), but adding a case breaks no client. **This is
worthwhile only for a published package**; inside an app it is needless machinery.

---

## SOLID in Swift: What Transfers and What Does Not

SOLID was coined for object-oriented programming with inheritance. Swift is a language of value types and protocols, so the translation is not direct.

| Principle | Verdict | In Swift |
|---|---|---|
| **S** Single Responsibility | Transfers | Carries over as a smell. A view that handles networking, persistence, and layout has three reasons to change |
| **O** Open/Closed | Dissolves | What OOP often achieves through inheritance can be handled with `extension`, even on external types. There is nothing extra to apply |
| **L** Liskov Substitution | No landing spot | Structs and enums do not inherit, and classes are written `final`. Without hierarchies, there is no substitution to guarantee |
| **I** Interface Segregation | Native | `Equatable`, `Hashable`, `Sendable`, `Identifiable` — minimal and composable protocols. Not something you apply; the language already thinks that way |
| **D** Dependency Inversion | Transfers, and matters most | The abstraction is a protocol and injection uses `@Environment`—no DI container or factory registry. See [architecture.md](architecture.md#dependency-injection-three-mechanisms-one-rule) |

The two that “dissolve”, in one line each:

```swift
// OCP: where in OOP you would make a subclass, here you extend — even foreign types.
extension String {
    var isEmptyOrWhitespace: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// ISP: no fat interfaces to segregate; compose minimal protocols.
struct Note: Identifiable, Equatable, Codable, Sendable { … }
//            ↑ four independent capabilities, not one hierarchy
```

And the one you apply every day:

```swift
// DIP: depends on the protocol, not the implementation.
protocol NoteRepository: Sendable {
    func loadAll() async throws -> [Note]
}

struct FileNoteRepository: NoteRepository { … }      // production
struct InMemoryNoteRepository: NoteRepository { … }  // tests & previews

// And injection is the framework’s mechanism, without DI container:
extension EnvironmentValues {
    @Entry var noteRepository: any NoteRepository = FileNoteRepository()
}
```

Practical conclusion: **keep SRP as a design smell and DIP as a mechanism**.
The other three are either automatic or inapplicable. Be wary of any design
that requires an inheritance hierarchy to explain it: Swift almost always has
a simpler protocol-based composition.

## Isolation and Protocol Requirements

The DIP rule above tells you to depend on a protocol. **How you declare that protocol
decides whether an actor or a `@MainActor` type can ever conform to it**, and getting it
wrong is discovered late, when the implementation you wanted to swap in turns out to be
the isolated one.

**Verified** (Swift 6.2.4, `-swift-version 6`), same protocol shape each time:

| Protocol | Requirements | Conformer | Result |
|---|---|---|---|
| `: Sendable` | `async` | `actor`, `@MainActor class`, `struct` | **all compile** |
| `: Sendable` | synchronous | `actor` | `error: conformance … crosses into actor-isolated code` |
| `: Sendable` | synchronous | `@MainActor class` | same error |
| *not* `Sendable` | synchronous | `@MainActor class` | **same error** |
| *not* `Sendable` | synchronous | `@MainActor class`, conformance written `: @MainActor P` | compiles |
| `: Sendable` | synchronous | `@MainActor class`, conformance written `: @MainActor P` | `error: cannot form … conformance to SendableMetatype-inheriting protocol` |

Two things follow, and the second contradicts the explanation that circulates.

**1. Make service protocol requirements `async`.** Row 1 is the whole answer: with `async`
requirements the same protocol is satisfiable by a struct, an actor and a main-actor
class alike, so the abstraction survives the implementation changing isolation later.
This is why the repositories in this skill read

```swift
protocol NoteRepository: Sendable {
    func loadAll() async throws -> [Note]     // async: any isolation can satisfy it
}
```

and it costs nothing — `async` on a requirement a struct fulfils synchronously is free.

**2. `Sendable` on the protocol is not what breaks synchronous requirements.** The
explanation you will read is that inheriting `Sendable` makes members `nonisolated`. Row 4
disproves it: a protocol with **no** `Sendable` at all rejects the same conformance with
the same diagnostic. The cause is the synchronous requirement itself — a caller in any
isolation domain must be able to invoke it, and an isolated member cannot promise that.

What `Sendable` actually changes is **the escape hatch**. Swift 6.2 lets you write an
isolated conformance (`: @MainActor P`, row 5) — and inheriting `Sendable` forbids exactly
that (row 6). So marking a protocol `Sendable` out of habit removes the option you would
have wanted.

An isolated conformance is also narrower than it looks: the conforming value cannot leave
its actor.

```swift
@MainActor final class Store: @MainActor Reporting { … }

Task.detached { await consume(store) }
// error: main actor-isolated conformance of 'Store' to 'Reporting'
//        cannot be used in nonisolated context
```

That is a fair trade for a type that is main-actor state anyway, and a dead end for one
that has to be handed to a background worker.

**Do not reach for `nonisolated(unsafe)`.** It appears in write-ups as the fix for row 2,
and it does compile — because it removes the actor's protection from that stored property
entirely. It is an assertion that you have handled the synchronisation yourself, and in a
service protocol you almost certainly have not. Change the requirement to `async` instead.

`swift-concurrency` covers actors, `Sendable` and isolation as a subject. This section is
only the part that decides how the protocols in [architecture.md](architecture.md#dependency-injection-three-mechanisms-one-rule)
are declared.

## Sources

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) — official.
- Server-side Swift practices (in a Hummingbird context): generics over
  existentials, structured concurrency, and `final` by default.
- [Learning Swift Concurrency](https://christiantietze.de/posts/2025/11/learning-swift-concurrency-matt-massicotte-with-zettelkasten/),
  Christian Tietze — raised the actor-vs-protocol-conformance tension. Its diagnosis
  (that `Sendable` on the protocol makes members `nonisolated`) and its remedy
  (`nonisolated(unsafe)`) are both corrected above, against the compiler.
