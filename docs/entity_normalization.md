# Entity Normalization Guide

Entity normalization consolidates similar entity values to improve search quality and reduce redundancy.

## Quick Start

1. **Preview changes** (no modifications):
   ```bash
   rails search:preview_normalization
   ```

2. **Backup current entities**:
   ```bash
   rails search:backup_entities
   ```

3. **Apply normalization**:
   ```bash
   rails search:normalize_entities
   ```

## How It Works

The `EntityNormalizationService` applies these transformations:

### Activities
- `workshop`, `workshops`, `class`, `classes` → `class/workshop`
- `party`, `parties`, `music party`, `dance party` → `music/party`
- `art`, `arts`, `craft`, `crafts` → `arts & crafts`
- `drinks`, `drink`, `beverage`, `cocktails` → `beverages`
- `yoga`, `movement`, `fitness`, `exercise` → `yoga/movement`

### Themes
- `musical`, `musician`, `musicians` → `music`
- `communal`, `commune`, `communities` → `community`
- `parties`, `celebration`, `celebrate` → `party`

### Locations
- `playa`, `deep playa`, `open-playa` → `open playa`
- `brc`, `black rock` → `black rock city`

### General Rules
- Converts to lowercase (activities/themes)
- Removes simple plurals
- Normalizes whitespace and punctuation

## Rollback

To undo normalization, restore from your backup:
```bash
rails search:restore_entities[tmp/entity_backup_TIMESTAMP.csv]
```

## Impact Example

Before normalization:
- `Class/Workshop` (378 occurrences)
- `workshop` (78 occurrences)
- `workshops` (217 occurrences)

After normalization:
- `class/workshop` (673 occurrences)

This consolidation improves search result quality by treating semantically identical entities as one.