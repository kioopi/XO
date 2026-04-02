# Move Resource Design

## Context

The Move resource (`Xo.Games.Move`) exists but is incomplete — it has attributes and relationships but no create action, no identities, and no connection to Game's `make_move` action. Game's `make_move` currently just transitions state without recording moves. We need to complete Move so that game history is recorded as append-only move records, with Game calculations deriving whose turn it is and what the next move number should be.

## Architecture

### Game additions

Game gets a `has_many :moves` relationship and derived values:

- **Relationship** `has_many :moves, Xo.Games.Move`
- **Aggregate** `count :move_count, :moves`
- **Calculation** `next_move_number : :integer` — `expr(move_count + 1)`
- **Calculation** `next_player_id : :uuid` — `expr(if(rem(move_count, 2) == 0, player_o_id, player_x_id))`

Player_o goes first. When `move_count` is 0 (even), it's player_o's turn (move_number 1). When `move_count` is 1 (odd), it's player_x's turn (move_number 2). And so on.

### Game.make_move delegates via manage_relationship

A custom change module `Xo.Games.Changes.CreateMove` on Game's `make_move` action uses `Ash.Changeset.manage_relationship/4` to create a Move through the `has_many :moves` relationship:

```elixir
Ash.Changeset.manage_relationship(changeset, :moves, [%{field: field}], type: :create)
```

This passes only `:field` to the Move. The `game_id` is set automatically by the relationship. The actor propagates from Game's action context.

`make_move` needs `require_atomic? false` because of the relationship management.

### Move create action

Move's `create` action is self-contained:

- **Accepts** `[:field]`
- **`relate_actor(:player)`** — sets player from the actor (idiomatic Ash)
- **Before action change** (`Xo.Games.Move.Changes.DeriveFromGame`) — loads the game (via `game_id` on the changeset) with `next_move_number` and `next_player_id` calculations, then sets `move_number` from `next_move_number`
- **Validation** (`Xo.Games.Move.Validations.ValidatePlayerTurn`) — loads the game's `next_player_id` and checks that the actor matches. Returns error if it's not their turn.

### Identities (persistence constraints)

On Move:
- `unique_field_per_game` on `[:game_id, :field]` — no field taken twice in same game
- `unique_move_number_per_game` on `[:game_id, :move_number]` — no duplicate move numbers

### Move test generator

`Xo.Generators.Move` in `test/support/generators/move_generator.ex`:
- Follows existing pattern (Ash.Generator, changeset_generator)
- Accepts overrides including `:game` and `:actor`
- Auto-creates an active game with two players if not provided
- Passes `:field` and lets Move.create derive the rest

## Files to change

| File | Action | What |
|------|--------|------|
| `lib/xo/games/game.ex` | Modify | Add `has_many :moves`, aggregates, calculations, update `make_move` with `require_atomic? false` and `CreateMove` change |
| `lib/xo/games/move.ex` | Modify | Add identities, create action with `relate_actor`, `DeriveFromGame` change, `ValidatePlayerTurn` validation |
| `lib/xo/games/changes/create_move.ex` | Create | Custom change on Game: manage_relationship to create Move with field value |
| `lib/xo/games/move/changes/derive_from_game.ex` | Create | Before action change: loads game calcs, sets move_number |
| `lib/xo/games/move/validations/validate_player_turn.ex` | Create | Validates actor matches game's next_player_id |
| `test/xo/games/move_test.exs` | Create | Tests for Move create, identities, turn validation |
| `test/xo/games/game_test.exs` | Modify | Tests for calculations and make_move → Move creation |
| `test/support/generators/move_generator.ex` | Create | Test generator |

## Verification

1. `mix test test/xo/games/move_test.exs` — Move create, identity constraints, turn validation
2. `mix test test/xo/games/game_test.exs` — Calculations, make_move delegation
3. `mix test` — Full test suite passes
4. `mix precommit` — All checks pass
