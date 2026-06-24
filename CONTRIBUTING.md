# Contributing to aricie

Thank you for your interest in contributing to aricie! This document provides guidelines and conventions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Branch Naming Convention](#branch-naming-convention)
- [Commit Convention](#commit-convention)
- [Pull Request Process](#pull-request-process)
- [Code Style](#code-style)
- [Testing](#testing)
- [Documentation](#documentation)
- [Security](#security)

## Code of Conduct

This project adheres to a code of conduct that promotes respect, inclusivity, and constructive collaboration. By participating, you are expected to uphold these values.

## Getting Started

1. Ensure you have Flutter installed (latest stable)
2. Clone the repository
3. Run `flutter pub get` to install dependencies
4. Create a `.env` file or use `--dart-define` flags for Supabase credentials

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Development Workflow

1. Create a feature branch from `main`
2. Implement your changes following the [Clean Architecture](docs/domain/domain.md) conventions
3. Write or update tests
4. Run static analysis: `flutter analyze`
5. Run tests: `flutter test`
6. Commit using [Conventional Commits](#commit-convention)
7. Push and create a Pull Request

## Branch Naming Convention

Branches must follow this naming pattern:

```
<type>/<short-description>
```

Types:
- `feat/` — new feature
- `fix/` — bug fix
- `refactor/` — code refactoring
- `docs/` — documentation changes
- `test/` — test additions or improvements
- `chore/` — maintenance tasks, dependency updates
- `security/` — security fixes

Examples:
- `feat/admin-panel`
- `fix/mqtt-reconnection`
- `refactor/auth-service`
- `docs/api-endpoints`

## Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/).

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`, `security`
Scopes: `auth`, `devices`, `license`, `admin`, `sync`, `core`, `data`, `domain`, `ui`, `mqtt`, `supabase`, `deps`

Examples:
```
feat(auth): add login use-case with session persistence
fix(mqtt): handle broker disconnection gracefully
refactor(domain): migrate Device entity to sealed class
docs(api): add endpoint documentation for sync
```

## Pull Request Process

1. Ensure your branch is up to date with `main`
2. Fill out the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md) completely
3. Verify all checklist items are addressed
4. Request review from at least one maintainer
5. Address all review feedback
6. Ensure CI passes (static analysis + tests)
7. Squash merge is required — all commits in a PR are squashed into one

### PR Title Convention

Follow the same convention as commits:

```
<type>(<scope>): <description>
```

### Review Requirements

- All `flutter analyze` warnings must be resolved
- All tests must pass
- No hardcoded secrets or credentials
- New features require corresponding tests
- Security-sensitive changes require security review

## Code Style

- **Language**: Dart 3 with strict typing, no `dynamic` or `any`
- **Architecture**: [Clean Architecture](docs/core/core.md) with layers: `core/` → `data/` → `domain/` → `presentation/`
- **State Management**: Riverpod (preferred), Provider (theme only)
- **Error Handling**: Sealed `Failure` hierarchy with `Either<Failure, T>` pattern
- **Navigation**: `Navigator.push` / `pushReplacement` (no GoRouter)
- **User-facing strings**: All in French
- **Naming**:
  - Files: `snake_case.dart`
  - Classes: `PascalCase`
  - Variables/methods: `camelCase`
  - Constants: `camelCase` (lowercase)
- **Imports**: Group as: `dart:`, `package:`, relative (`../`)

## Testing

- **Unit tests**: Required for all use-cases and entities
- **Widget tests**: Required for all screens
- **Test framework**: `flutter_test` + mocktail
- **BDD scenarios**: Defined in `test_driver/features/` using Gherkin syntax
- **Run tests**: `flutter test`
- **Run driver tests**: `flutter drive --target=test_driver/app.dart`

Tests must be added in the same PR as the feature or fix they validate.

## Documentation

- All new screens and features must be documented in `docs/`
- Update `AGENTS.md` with new entry points or conventions
- Update `README.md` if user-facing functionality changes
- Architecture decisions should be documented in `docs/superpowers/`

## Security

- Follow the [Security Policy](SECURITY.md) (OMT_2024_v2)
- No secrets in source code — use `--dart-define` or `.env`
- Sensitive data must use `flutter_secure_storage`, never `shared_preferences`
- All external communication must use TLS/SSL
- Production builds must use `--obfuscate --split-debug-info`
- Report vulnerabilities by opening an issue with the `security` label
