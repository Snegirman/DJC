# DJC

DJC is a native iOS app for organizing dance jam groups during classes.

The app is built for three dance styles:

- Popping
- Animation
- Waving

Each style has its own jam history. When generating new groups, the app only uses previous jams from the selected style, so Popping history does not affect Animation or Waving, and vice versa.

## Features

- Add dancers by nickname.
- Edit dancer profile fields:
  - Display name
  - Nickname
  - First name
  - Last name
- View dancer stats:
  - total saved jams;
  - attendance by style;
  - most frequent jam partners.
- Soft-delete dancers without losing their jam history.
- Confirm before soft-deleting a dancer.
- Restore archived dancers.
- Select the current dance style.
- Mark present dancers for a class.
- Generate jam groups with a minimum group size of 3.
- Regenerate groups before confirming a jam.
- Keep group sizes as even as possible.
- Confirm a jam before saving it to local history.
- View saved jam history with style, date, and group rosters.
- Delete mistakenly saved jams from history.
- Export saved jam history as a `.csv` file.
- Import previously exported CSV backups.
- Import a CSV backup into an empty app installation.

## Group Generation

The group generation logic lives outside SwiftUI and SwiftData in `JamOptimizer`.

The optimizer currently:

- keeps groups at 3 or more dancers;
- distributes dancers as evenly as possible;
- considers only history for the selected dance style;
- penalizes repeated dancer pairs;
- accounts for repeated-pair frequency relative to attendance;
- gives more weight to recent repeated meetings;
- penalizes repeating the exact same whole group.
- evaluates rotated, reversed, round-robin, and deterministic seeded shuffle candidates.
- exposes scoring weights through `JamOptimizer.Configuration`.

This separation makes the algorithm testable without UI or persistence.

## Tech Stack

- Swift
- SwiftUI
- SwiftData
- Swift Testing
- Local-first storage
- CSV export for history backup/sharing

There is no backend and no iCloud sync at this stage.

## Project Structure

```text
DJC/
  DJC/
    ContentView.swift
    DJCApp.swift

    Models/
      Dancer.swift
      DanceStyle.swift
      Jam.swift
      JamGroup.swift

    Optimizer/
      JamOptimizer.swift
      JamOptimizerInput.swift
      JamOptimizerResult.swift

    Export/
      JamCSVExporter.swift
      JamCSVImporter.swift
      JamCSVDocument.swift

    Features/
      Dancers/
        DancerListSection.swift
        ArchivedDancersSection.swift
        DancerEditView.swift
        DancerStats.swift
      History/
        HistorySection.swift
        JamHistoryViews.swift
      JamGeneration/
        GeneratedGroupsSection.swift

  DJCTests/
    DJCTests.swift
```

## Data Model

`Dancer` stores dancer identity and profile fields. Jam history is connected to the dancer's stable `id`, so changing names does not break history.

Archived dancers are hidden from active class attendance, but their saved jam history remains available. They can be restored from the Archived Dancers section.

`DanceStyle` is a fixed enum for `popping`, `animation`, and `waving`.

`Jam` represents one confirmed jam for one style.

`JamGroup` stores the dancers assigned to one group inside a jam.

## CSV Export

The CSV export includes:

- jam ID
- date
- style
- group index
- dancer ID
- dancer display name
- dancer nickname
- dancer first name
- dancer last name

The format is intentionally row-based: one dancer per CSV row. This is easy to open in Numbers, Excel, or Google Sheets and can later be used for import/backup logic.

The app exports CSV through the system file exporter with a filename like `djc-jams-2026-09-01.csv`.

## CSV Import

The app can import CSV files that use the DJC export format. Existing jams with the same jam ID are skipped to avoid duplicate history. Existing dancers with matching dancer IDs are updated and restored if archived; missing dancers are created.

After import, the app reports how many new jams were restored.

## Testing

Business logic tests are in `DJCTests`.

Current test coverage focuses on:

- valid group-size calculation;
- edge cases for small and uneven dancer counts;
- typical class sizes from 15 to 20 dancers;
- generated groups preserving every present dancer exactly once;
- rejecting fewer than 3 dancers;
- avoiding repeated pairs when possible;
- ignoring history from other dance styles;
- penalizing repeated groups in the same style;
- scoring weights, pair frequency, and recency behavior.
- CSV import validation errors for malformed backup files.

Run tests from Xcode with the `DJC` scheme.

## Current Scope

The app is currently an early working version. The main UI is intentionally simple while the core model and algorithm are being built.

Planned next steps:

- tune optimizer scoring weights based on real class usage;
- add more tests for larger real-world attendance cases.
