# Contributing to Schedulify

Thanks for your interest in contributing! Here's everything you need to get started.

## Dev Setup

1. Install Flutter 3.32+ (stable channel)
2. Install Android Studio + SDK 36
3. Clone the repo and run `flutter pub get`
4. Create `dart_defines.json` (see README)
5. Launch an emulator and run `flutter run --dart-define-from-file=dart_defines.json`

## Commit Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — new feature
- `fix:` — bug fix
- `chore:` — build/config changes
- `docs:` — documentation only
- `refactor:` — code restructuring
- `test:` — adding or fixing tests

## Branch Naming

```
feat/your-feature
fix/issue-description
chore/task-name
```

## Pull Request Checklist

- [ ] `flutter analyze` passes with no errors
- [ ] Tested on emulator or physical device
- [ ] No secrets committed (check `dart_defines.json` is gitignored)
- [ ] PR description explains what changed and why
