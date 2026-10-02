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
- Suggest the dancer with the fewest recorded starts in each group and change the starter before saving.
- Keep group sizes as even as possible.
- Confirm a jam before saving it to local history.
- View saved jam history with style, date, and group rosters.
- Record past jams manually with a chosen style, date, time, and group rosters.
- Delete mistakenly saved jams from history.
- Export saved jam history as a `.csv` file.
- Import previously exported CSV backups.
- Import a CSV backup into an empty app installation.

## Recording a Past Jam

Use **Add Past Jam** above History to record a jam held without the app. Choose
the style and date/time, then open each group to select its dancers. Add groups
as needed or swipe left to remove one. Each group needs at least 3 dancers, and
each dancer can appear only once in the jam; uneven group sizes are allowed.

Archived dancers can be selected without restoring them. Add any missing dancers
on the main screen first. Save writes the jam to history with the chosen date;
Cancel discards the draft. The saved jam participates in statistics, CSV backups,
and future group generation for its style. Existing generated groups are cleared
after saving so they can be regenerated using the updated history.

## Group Generation

Each generated group has a **Starts first** picker. The suggestion uses the number
of saved starts in the selected dance style, across all earlier group compositions.
Only group members are eligible; ties are resolved by stable dancer ID. You can
choose any member before confirming. Only the saved choice counts toward future
starts; regenerating groups does not count. The starter is also marked in history.

Old history and manually recorded past jams have an unknown starter and do not add
to start counts. Changing styles clears generated groups so the next suggestion
uses the correct history.

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
Its explicit many-to-many relationship with `Dancer.groups` preserves membership
when the same dancer participates in later jams. Deleting a jam cascades to its
groups and removes their links, without deleting the dancers.

`JamMigrationPlan` transfers existing group membership by stable IDs when upgrading
the original database to the many-to-many schema. `JamSchemaV1` preserves the old
model definition for this migration. Membership already lost before the upgrade
cannot be reconstructed automatically.

`JamSchemaV2` preserves the many-to-many schema before starter tracking. Version 3
adds an optional `startingDancerID` to each group, leaving it empty in old history.

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
- starts first (`true` for the starter, `false` otherwise; all false when unknown)

The format is intentionally row-based: one dancer in one group of one jam per CSV row. The app itself stores history in a local SwiftData database; CSV is a portable export for backup/import.

The app exports CSV through the system file exporter with a filename like `djc-jams-2026-09-01.csv`.

## CSV Import

The app can import CSV files that use the DJC export format. Existing jams with the same jam ID are skipped to avoid duplicate history. Existing dancers with matching dancer IDs are updated and restored if archived; missing dancers are created.

After import, the app reports how many new jams were restored.
Older CSV files without `starts_first` are still accepted, with unknown starters.

### Как читать CSV

Откройте файл как таблицу с кодировкой UTF-8 и разделителем «запятая».
Одна строка — участие одного танцора в одной группе одного джема.
Например, джем из двух групп по три человека занимает шесть строк.

| Колонка | Значение |
| --- | --- |
| `jam_id` | Постоянный ID джема. Совпадает у всех строк одного джема. |
| `date` | Время джема в UTC: `2026-09-06T12:00:00Z` — это 15:00 в Москве. |
| `style` | `popping`, `animation` или `waving`. |
| `group_index` | Номер группы внутри джема, начиная с 1. |
| `dancer_id` | Постоянный ID танцора. Не меняется при переименовании. |
| `dancer_display_name` | Имя, показываемое в приложении на момент экспорта. |
| `dancer_nickname` | Никнейм. |
| `dancer_first_name` | Имя из профиля, может быть пустым. |
| `dancer_last_name` | Фамилия из профиля, может быть пустой. |
| `starts_first` | `true` у начинающего, `false` у остальных. Если начинающий неизвестен, у всей группы `false`. В старых файлах колонки нет. |

Для просмотра удобно скрыть колонки с ID и сгруппировать строки по джему
и номеру группы. Не удаляйте ID из файла для восстановления: они позволяют
отличать одноимённых людей и не создавать дубликаты джемов. Дата, стиль и ID
повторяются в строках намеренно, чтобы каждая строка однозначно описывала участие.
Запятые, кавычки и переносы строк внутри имени экранируются средствами CSV.

Ограничения текущего экспорта и импорта:

- Экспорт содержит все стили, но только сохранённые джемы и их участников.
  Люди, которые ещё не участвовали ни в одном сохранённом джеме, не попадают в файл.
- Это не полная копия приложения: настройки, отметки присутствия, несохранённые
  группы и статус архива не переносятся.
- Имена берутся из текущих профилей, а не из снимка профиля на дату занятия.
- Импорт добавляет только джемы с новыми `jam_id`. Уже имеющийся джем пропускается
  целиком; его состав не исправляется и профили из его строк не обновляются.
- Для добавляемых джемов люди сопоставляются по `dancer_id`, их профили обновляются,
  а архивные участники восстанавливаются. Отсутствующие в файле данные не удаляются.

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
