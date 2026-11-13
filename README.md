# Say Again: Aussie Interviews

[![CI](https://github.com/flakyhunter/SayAgain/actions/workflows/ci.yml/badge.svg)](https://github.com/flakyhunter/SayAgain/actions/workflows/ci.yml)

A free iOS app that helps you **understand Australian job interview questions by ear**:
the accent, the slang, and the way interviewers really ask things
("Righto, last one from me...", "Have you had a crack at...").

You listen to a question first, pick what you think they asked, then see the original text,
a plain-English version and the phrases that usually trip people up.

> Status: **v0 - project skeleton.** The practice loop is coming in v1.

## Why this repo exists

This is a personal portfolio project by a QA automation engineer. The app is small on purpose;
the focus is on how it is tested and shipped:

- a test pyramid with fast unit tests at the bottom and a few stable UI tests at the top,
- a deterministic UI-test mode (no network, fixed content, no animations),
- page objects and shared accessibility identifiers instead of text-based queries,
- content that is validated by tests like code,
- CI on every push and pull request.

## Test strategy

| Level | Tooling | What it covers | Runs on |
|---|---|---|---|
| Unit | Swift Testing, `swift test` | Content rules, category summaries, decoding errors | macOS, seconds |
| Snapshot | [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | Home screen in light, dark and empty states | iOS Simulator |
| UI | XCUITest + page objects | User-visible flows in deterministic mode | iOS Simulator |

Key decisions:

- **Shared contract.** `SayAgainKit` exposes `A11yID` and `LaunchArgument`, used by both the app
  and the UI tests, so a renamed identifier breaks the build, not a test run.
- **Deterministic UI tests.** `-uiTesting` swaps in fixture content and turns off animations.
  Tests wait on elements, never on `sleep`.
- **Content is code.** Every question must pass the validator: unique ids, exactly two
  distractors, no distractor equal to the answer, no empty fields, typography rules.

## Project layout

```
App/                     SwiftUI app target (thin: views + launch environment)
AppTests/                Snapshot and environment tests (hosted)
UITests/                 XCUITest scenarios and page objects (Screens/)
Packages/SayAgainKit/    Models, content, validation, test contract - no UI
project.yml              XcodeGen spec (the .xcodeproj is generated, not committed)
```

## Run locally

Requires Xcode 26.1+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
swift test --package-path Packages/SayAgainKit
xcodebuild test -project SayAgain.xcodeproj -scheme SayAgain \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

## Roadmap

- **v0** - skeleton, first tests on every level, CI. *(current)*
- **v1** - practice loop (listen, choose, reveal, self-rate), spaced repetition, 60+ questions,
  TestFlight from CI, App Store release.
- **v2** - AI feedback on your retelling of the question, covered by an LLM eval suite in CI.

## Privacy

No accounts, no analytics, no tracking. Progress stays on the device. Speech is generated
on the device by the system voices.

## License

MIT
