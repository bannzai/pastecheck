---
paths:
  - "**/*.swift"
---

# Swift coding conventions

- Write the design intent (why, constraints) in `///` doc comments. Do not describe what the code does
- Separate components with side effects (reading NSPasteboard, notifications, the file system, UI state) from pure logic (`enum` + `static func`, or value types), and put the pure logic in `PasteCheckCore` as the target of unit tests
- One responsibility per file. Name a test file after the file it tests (`Xxx.swift` ⇔ `XxxTests.swift`)
- Custom `Error` types implement `CustomStringConvertible`, and error messages are shown as is without modification
- Make functions idempotent. When a function cannot be idempotent, state the reason in a comment
- Use Swift Testing for unit tests
- Do not write the `{ }` block of a statement such as `if` / `guard` / `for` / `while` / `defer` / `Task` on one line (expand it over multiple lines). Single-expression computed properties and expression closures such as `items.map { $0.name }` are exempt
