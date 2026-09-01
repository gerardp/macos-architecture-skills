# View Composition

How to keep a reusable presentation component from filling up with optional
properties and conditionals. This is the third axis, alongside
[narrow inputs](previews.md#1-narrow-inputs-not-full-models) and
[events grouped in an enum](architecture.md#events-grouped-in-an-enum).

## The Problem: Multiplying Optionals and Conditionals

A row that sometimes shows time, sometimes a button, and sometimes nothing,
written based on optional properties:

```swift
// Wrong — each new variant adds an optional property and an `if let`.
struct Stop: View {
    let title: String
    let systemImage: String
    var time: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                Text(title)
            }
            Spacer()
            if let time { Text(time) }
            if let action {
                Button(action: action) { Image(systemName: "map") }
            }
        }
    }
}
```

It is not *incorrect*, but it does not scale: every customization adds a
property, a conditional, and another nesting level.

## The Shortcut That Makes Things Worse: Passing the Entire Model

```swift
// Reduces properties, yes. But ties the view to the model layer,
// makes it non-reusable in any other context, and complicates the preview.
struct Stop: View {
    let transitStop: TransitStop
}
```

This is the shortcut almost everyone takes when parameters grow. It changes a
visible problem (many parameters) into an invisible one (tight coupling).

## Approach 1: Dedicated Views Instead of Nested Stacks

Before stacking `HStack` + `Image` + `Text` + `Spacer` and tweaking modifiers
by eye, check if SwiftUI already has the view. `Label` and `LabeledContent` not
only remove nesting: **they inherit the style of their container**. Inside a
`List`, the images of a `Label` appear with the correct size, aligned, and tinted,
without a single modifier.

```swift
Label(title, systemImage: systemImage)          // instead of HStack { Image; Text }
LabeledContent { accessory } label: { … }       // instead of HStack { …; Spacer(); … }
```

## Approach 2: Pass Views as Parameters with `@ViewBuilder`

The underlying solution. Instead of enumerating variants with optionals, let the
caller build the accessory.

```swift
struct Stop<Accessory: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        LabeledContent { accessory() } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

// A concrete default initializer that omits the accessory.
// Keep it in an extension so the memberwise initializer remains available.
extension Stop where Accessory == EmptyView {
    init(title: String, systemImage: String) {
        self.init(title: title, systemImage: systemImage) { EmptyView() }
    }
}
```

Usage:

```swift
List {
    Stop(title: "Your location", systemImage: "circle.circle.fill")
    Stop(title: "Marnixplein", systemImage: "tram") {
        Text("12:07")
    }
    Stop(title: "Elandsgracht", systemImage: "mappin.and.ellipse.circle") {
        TransportTag(line: "5")
        TransportTag(line: "7")
    }
}
```

**Verified**: compiles with a **macOS 14** deployment target (Swift 6.2).

Three required details that are not obvious:

1. **It has to be generic.** The caller defines the return type of the view
   builder, so `Accessory` is a type parameter constrained to `View`. You
   cannot use `some View` in a stored property.
2. **The default value is given with `where Accessory == EmptyView`**, not with an
   optional. An optional `@ViewBuilder` causes compilation problems in some calls.
3. **Custom initializers go in an extension**, or you lose the initializer by
   memberwise initializer synthesized by Swift.

## Approach 3: Use `ViewModifier` for Repeated Styling

When what repeats is not structure but **appearance**, you don’t need a new view.
A `ViewModifier` can be applied to any view —`Text`, `Image`, `Button`— which a
custom `struct View` cannot.

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.background.secondary, in: .rect(cornerRadius: 8))
            .shadow(radius: 1, y: 1)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

// Usage: Text("…").cardStyle()  ·  NoteRowView(…).cardStyle()
```

The extension on `View` gives you the dot syntax. Without it, you’d have to write
`.modifier(CardStyle())` on every call.

## Control Flow Inside `body`

The `body` is not a normal function: it is a **`@ViewBuilder`**, which changes
what constructions you can use and their consequences.

### `guard` Exits the View Builder

`guard` forces an explicit `return`, and as soon as you write a `return` the body
**stops being a view builder and becomes a normal function returning `some View`**.
Consequence: **all branches must return the same concrete type**.

```swift
// Wrong — does not compile: branches return different types.
var body: some View {
    guard let name else { return ProgressView() }
    return Text(name)
}
```

```
error: function declares an opaque return type 'some View', but the return
statements in its body do not have matching underlying types
```

```swift
// Right — inside the builder: `if let` supports branches of different types.
var body: some View {
    if let name { Text(name) } else { ProgressView() }
}
```

**Verified** by compiling both cases with a macOS 14 deployment target. `guard`
works when every branch has the same type, but that is a fragile coincidence:
as soon as one branch changes, compilation fails. Inside `body`, use `if let`
and `switch`; reserve `guard` for ordinary functions, where its real advantage—
avoiding a pyramid of nesting through early exit—actually applies.

### Ternaries: Good for One Value, Bad When Nested

```swift
// Right — a ternary for choosing a value is readable.
Text(title).foregroundStyle(isFavorite ? .yellow : .secondary)

// Wrong — nested: no one reads this twice.
Text(count == 0 ? "empty" : count == 1 ? "one note" : "\(count) notes")
```

```swift
// Right — if there are more than two cases, use a switch, and in Swift it’s an
// expression.
let label = switch count {
    case 0: "empty"
    case 1: "one note"
    default: "\(count) notes"
}
```

Rule: **one ternary is fine; extract two nested ternaries**. If the condition
chooses which *view* to show rather than which *value* to use, put `if`/`switch`
inside the builder, where branches may also have different types.

## When to Use Each Tool

| Situation | Tool |
|---|---|
| The view shows fixed data | Narrow properties (`let`) |
| The view notifies actions | [Event enum](architecture.md#events-grouped-in-an-enum) |
| Content varies depending on who uses it | **Generic `@ViewBuilder`** |
| Only the appearance changes, not the structure | **`ViewModifier`** + extension of `View` |

## Source

- [SwiftUI Views](https://matteomanferdini.com/swiftui-views/), Matteo Manferdini.
