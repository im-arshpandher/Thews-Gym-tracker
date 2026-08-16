# Project: Thews — Gym Workout Tracker

## Overview
Cross-platform (Android + iOS) gym workout tracker. Manually log exercises, weight used, reps, and sets. Local-first storage, with architecture that allows a remote sync layer to be added later without restructuring.

## Stack
- **Framework:** Flutter (Dart)
- **State management / DI:** Riverpod
- **Local storage:** Drift (SQLite) — relational, type-safe queries, fits set/rep/weight data well
- **Navigation:** go_router

## Architecture: Modular Monolith
Single deployable app, split into independent feature modules with clear boundaries. Each module owns its own data/domain/presentation layers and talks to others only through defined interfaces — no direct cross-module reach-ins. Keeps the codebase swappable/testable per module without going full microservice/multi-package complexity.

### Modules
- **core** — DB instance, shared models/utils, router, app-wide state
- **exercises** — exercise library (predefined + user-created), muscle group tagging
- **workouts** — workout session logging: exercises performed, sets, reps, weight
- **history** — past workout sessions, per-exercise progress over time
- **settings** — units (kg/lb), theme mode toggle (functional switch only)

## Folder Structure
```
lib/
  core/
    database/
    models/
    utils/
    router/
  features/
    exercises/
      data/
      domain/
      presentation/
    workouts/
      data/
      domain/
      presentation/
    history/
      data/
      domain/
      presentation/
    settings/
      data/
      domain/
      presentation/
  main.dart
```
Each feature follows: `data` (local data source, repository impl) → `domain` (entities, repository interface, use cases) → `presentation` (screens, controllers/providers).

## Data Model (local)
- **Exercise** — id, name, muscleGroup, isCustom
- **Workout** — id, date, notes, durationSeconds
- **WorkoutExercise** — id, workoutId, exerciseId, order
- **SetEntry** — id, workoutExerciseId, setNumber, weight, reps, unit

## Core Features
- Manual exercise selection/creation
- Log sets per exercise: weight, reps, set number
- Start/end workout session with duration tracking
- Workout history list, drill into any past session
- Per-exercise progress view (weight/volume over time, PR tracking)
- Unit preference: kg/lb
- Theme mode toggle: light/dark (setting only — no color/style specs here)
- 100% local persistence, no account required

## Sync-Readiness
Repository pattern in each module's `data` layer abstracts the source (local DB now, remote API later) so a sync module can be added without touching `domain`/`presentation` layers.

## Proposed Dependencies
- `flutter_riverpod`
- `drift` + `sqlite3_flutter_libs`
- `go_router`
- `freezed` + `json_serializable` (optional, for immutable models)