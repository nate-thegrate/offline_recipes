# Documentation

Documentation (comments and `.md` files) should be concise and current. State what is true now; don’t catalog past mistakes or discarded approaches.

Prefer self-documenting code over comments. Never use comments as section banners:

```dart
// BAD: do not divide files with comment headers
// ── Home ─────────────────────────────────────────────────
```

# Tests

Test behavior and invariants.

Design tests in a way that mitigates friction for future changes: never write a tautological test that just asserts the existing configuration.

Pull values from the codebase instead of re-defining them: if it would be useful to access a private field from within a test, make the field public and add the `@visibleForTesting` annotation.

# Code style

**State management with signal_widgets:** Avoid using `setState`. Use signal objects as State member variables and globally-scoped signals for shared state. The widget's `extends` line is the subscribe contract: `SignalWidget` / `SignalStatefulWidget` means *this* `build` may read `.value` and will rebuild; `StatelessWidget` / `StatefulWidget` means it will not. To subscribe, either use a `Signal*` base class or a signal child such as `SignalSizedBox` or `SignalPaint`. To inventory `Signal*` widgets, use the dart-pubdev-explorer skill (`.agents/skills/dart-pubdev-explorer/`).

Circular imports under `lib/` are fine. Do not restructure dart libraries solely to avoid import cycles.

Use [dot shorthands](https://dart.dev/language/dot-shorthands) to improve readability, for instance when passing arguments to named parameters. (Avoid shortening unnamed constructors to `.new()`.)

Prefer full words for names. Short locals are fine when they match a common Flutter (or dependency) convention — e.g. `t` for animation progress, `i` for an index, `dx`/`dy` from `Offset`. Prefer [object destructuring](https://dart.dev/language/patterns#destructuring-class-instances) when using a single object to assign multiple locals:

```dart
void foo(Rect rect) {
  // BAD
  final Offset a1 = rect.topLeft;
  final Offset a2 = rect.bottomRight;

  // GOOD
  final Rect(:topLeft, :bottomRight) = rect;
}
```

In most cases, avoid defining global or `static` fields that are only used once; inline them at the use site.

Flutter hot reload cannot replace a closure captured in a `final` field initializer. Prefer using a tear-off; trivial one-line projections can stay inlined. (A tear-off is sometimes necessary to enable a `const` constructor: global functions and `static` methods can be used in a constant context whereas inline callbacks cannot.)

```dart
// OK: one-liner, unlikely to change
final stats = computed(() => _town.value.stats);

// GOOD: body can be edited and hot-reloaded
final _town = computed(_evaluateTown);
_Town _evaluateTown() { ... }
```

# Tools

## Dart MCP server

After Dart edits, run Dart MCP `analyze_files` on the whole project (omit `paths`). Do not use `dart analyze` for that pass. `flutter test` stays in the shell.

Call `analyze_files` with `applyFixes: false` first. If it reports diagnostics, call it again with `applyFixes: true`, and do not hand-edit in between. The second call applies quick fixes and may only say "Applied quick fixes". Read the diff to see the edits, and leave those edits in place. Hand-edit only diagnostics that remain.
