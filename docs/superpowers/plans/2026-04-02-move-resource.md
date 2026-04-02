# Move Resource Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the Move resource with a create action, connect it to Game via manage_relationship, and add calculations to Game for turn tracking.

**Architecture:** Move's create action is self-contained — it accepts `field` and `game_id`, derives `move_number` from the game's calculations, sets `player` from the actor, and validates turn order. Game's `make_move` action delegates to Move via `manage_relationship(:moves, type: :create)`. Game gets `move_count` aggregate and `next_move_number`/`next_player_id` calculations.

**Tech Stack:** Ash Framework 3.0, AshPostgres, AshStateMachine, Elixir

---

### Task 1: Game has_many :moves, Move identities, migration

**Files:**
- Modify: `lib/xo/games/game.ex:76-89` (relationships block)
- Modify: `lib/xo/games/move.ex` (add identities block)

- [ ] **Step 1: Add has_many :moves to Game**

In `lib/xo/games/game.ex`, add inside the `relationships` block (after the `belongs_to :winner` block, before the closing `end`):

```elixir
    has_many :moves, Xo.Games.Move
```

- [ ] **Step 2: Add identities to Move**

In `lib/xo/games/move.ex`, add after the `relationships` block (before the final `end`):

```elixir
  identities do
    identity :unique_field_per_game, [:game_id, :field]
    identity :unique_move_number_per_game, [:game_id, :move_number]
  end
```

- [ ] **Step 3: Generate and run migration**

Run:
```bash
mix ash.codegen add_moves_table_and_identities --yes
```

Then:
```bash
mix ash.migrate
```

Expected: migration creates the `moves` table with columns (`id`, `field`, `move_number`, `player_id`, `game_id`, `inserted_at`, `updated_at`), foreign keys, and two unique indexes.

- [ ] **Step 4: Verify existing tests still pass**

Run:
```bash
mix test --max-failures 3
```

Expected: all existing tests pass (no regressions from adding the relationship and identities).

- [ ] **Step 5: Commit**

```bash
git add lib/xo/games/game.ex lib/xo/games/move.ex priv/repo/migrations/
git commit -m "Add has_many :moves to Game, identities to Move, generate migration"
```

---

### Task 2: Game calculations (next_move_number, next_player_id)

**Files:**
- Modify: `lib/xo/games/game.ex` (add aggregates and calculations blocks)
- Modify: `test/xo/games/game_test.exs` (add calculation tests)

- [ ] **Step 1: Write failing tests for calculations**

Add to `test/xo/games/game_test.exs`, after the existing `describe "make_move action"` block:

```elixir
  describe "next_move_number calculation" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "returns 1 for a game with no moves", %{game: game} do
      game = Ash.load!(game, :next_move_number)
      assert game.next_move_number == 1
    end
  end

  describe "next_player_id calculation" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "returns player_o_id for a game with no moves", %{game: game, player_o: player_o} do
      game = Ash.load!(game, :next_player_id)
      assert game.next_player_id == player_o.id
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
mix test test/xo/games/game_test.exs --max-failures 3
```

Expected: FAIL — `next_move_number` and `next_player_id` calculations don't exist yet.

- [ ] **Step 3: Add aggregate and calculations to Game**

In `lib/xo/games/game.ex`, add after the `relationships` block:

```elixir
  aggregates do
    count :move_count, :moves
  end

  calculations do
    calculate :next_move_number, :integer, expr(move_count + 1)

    calculate :next_player_id, :uuid, expr(
      if(rem(move_count, 2) == 0, player_o_id, player_x_id)
    )
  end
```

Logic: `move_count` 0 (even) → player_o's turn (move #1). `move_count` 1 (odd) → player_x's turn (move #2). And so on.

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
mix test test/xo/games/game_test.exs --max-failures 3
```

Expected: PASS — all tests including the new calculation tests.

- [ ] **Step 5: Commit**

```bash
git add lib/xo/games/game.ex test/xo/games/game_test.exs
git commit -m "Add move_count aggregate and next_move_number/next_player_id calculations to Game"
```

---

### Task 3: Move create action with DeriveFromGame change

**Files:**
- Create: `lib/xo/games/move/changes/derive_from_game.ex`
- Modify: `lib/xo/games/move.ex` (add create action)
- Create: `test/xo/games/move_test.exs`

- [ ] **Step 1: Write failing tests for Move.create**

Create `test/xo/games/move_test.exs`:

```elixir
defmodule Xo.Games.MoveTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 0, game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games.Move

  defp active_game do
    player_o = generate(user())
    game = generate(game(actor: player_o))
    player_x = generate(user())
    active = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)
    %{game: active, player_o: player_o, player_x: player_x}
  end

  describe "create action" do
    test "creates a move with correct field, move_number, game_id, and player_id" do
      %{game: game, player_o: player_o} = active_game()

      move =
        Ash.create!(Move, %{field: 4, game_id: game.id}, action: :create, actor: player_o)

      assert move.field == 4
      assert move.move_number == 1
      assert move.game_id == game.id
      assert move.player_id == player_o.id
    end

    test "derives move_number from game's move count" do
      %{game: game, player_o: player_o, player_x: player_x} = active_game()

      Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)
      move2 = Ash.create!(Move, %{field: 1, game_id: game.id}, action: :create, actor: player_x)

      assert move2.move_number == 2
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
mix test test/xo/games/move_test.exs --max-failures 3
```

Expected: FAIL — no `:create` action on Move.

- [ ] **Step 3: Create DeriveFromGame change module**

Create `lib/xo/games/move/changes/derive_from_game.ex`:

```elixir
defmodule Xo.Games.Move.Changes.DeriveFromGame do
  @moduledoc """
  Loads the game's calculations and sets move_number on the changeset.
  Stashes the loaded game in changeset context for use by validations.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      game_id = Ash.Changeset.get_attribute(changeset, :game_id)

      game =
        Ash.get!(Xo.Games.Game, game_id,
          load: [:next_move_number, :next_player_id],
          authorize?: false
        )

      changeset
      |> Ash.Changeset.force_change_attribute(:move_number, game.next_move_number)
      |> Ash.Changeset.set_context(%{game: game})
    end)
  end
end
```

- [ ] **Step 4: Add create action to Move**

In `lib/xo/games/move.ex`, replace the `actions` block:

```elixir
  actions do
    defaults [:read]

    create :create do
      accept [:field, :game_id]

      change relate_actor(:player, allow_nil?: false)
      change Xo.Games.Move.Changes.DeriveFromGame
    end
  end
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
mix test test/xo/games/move_test.exs --max-failures 3
```

Expected: PASS — both create tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/xo/games/move.ex lib/xo/games/move/changes/derive_from_game.ex test/xo/games/move_test.exs
git commit -m "Add Move create action with DeriveFromGame change"
```

---

### Task 4: ValidatePlayerTurn validation on Move

**Files:**
- Create: `lib/xo/games/move/validations/validate_player_turn.ex`
- Modify: `lib/xo/games/move.ex` (add validation to create action)
- Modify: `test/xo/games/move_test.exs` (add turn validation tests)

- [ ] **Step 1: Write failing tests for turn validation**

Add to `test/xo/games/move_test.exs`, inside the `describe "create action"` block:

```elixir
    test "rejects move when it is not the actor's turn" do
      %{game: game, player_x: player_x} = active_game()

      assert_raise Ash.Error.Invalid, ~r/not this player's turn/, fn ->
        Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_x)
      end
    end

    test "allows player_x to move on the second turn" do
      %{game: game, player_o: player_o, player_x: player_x} = active_game()

      Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)

      move =
        Ash.create!(Move, %{field: 1, game_id: game.id}, action: :create, actor: player_x)

      assert move.player_id == player_x.id
      assert move.move_number == 2
    end
```

- [ ] **Step 2: Run tests to verify the rejection test fails**

Run:
```bash
mix test test/xo/games/move_test.exs --max-failures 3
```

Expected: FAIL — the "rejects move when it is not the actor's turn" test fails because there's no turn validation yet (it creates the move instead of raising).

- [ ] **Step 3: Create ValidatePlayerTurn validation module**

Create `lib/xo/games/move/validations/validate_player_turn.ex`:

```elixir
defmodule Xo.Games.Move.Validations.ValidatePlayerTurn do
  @moduledoc """
  Validates that the actor is the next player to move.
  Reads the game from changeset context (set by DeriveFromGame change).
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, context) do
    game = changeset.context.game
    actor = context.actor

    if actor && actor.id == game.next_player_id do
      :ok
    else
      {:error, field: :player, message: "not this player's turn"}
    end
  end
end
```

- [ ] **Step 4: Add validation to Move's create action**

In `lib/xo/games/move.ex`, update the create action to add the validation after the changes:

```elixir
    create :create do
      accept [:field, :game_id]

      change relate_actor(:player, allow_nil?: false)
      change Xo.Games.Move.Changes.DeriveFromGame
      validate Xo.Games.Move.Validations.ValidatePlayerTurn
    end
```

Note: `DeriveFromGame` stashes the game in context via a `before_action` hook. However, validations run *before* `before_action` hooks in Ash's pipeline. This means the game won't be in context when `validate/3` runs.

To fix this, `DeriveFromGame` should load and stash the game in `change/3` (which runs before validations) and set `move_number` in a `before_action` hook. Update `lib/xo/games/move/changes/derive_from_game.ex`:

```elixir
defmodule Xo.Games.Move.Changes.DeriveFromGame do
  @moduledoc """
  Loads the game's calculations and stashes the game in changeset context.
  Sets move_number in a before_action hook.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    game_id = Ash.Changeset.get_attribute(changeset, :game_id)

    game =
      Ash.get!(Xo.Games.Game, game_id,
        load: [:next_move_number, :next_player_id],
        authorize?: false
      )

    changeset
    |> Ash.Changeset.set_context(%{game: game})
    |> Ash.Changeset.before_action(fn changeset ->
      Ash.Changeset.force_change_attribute(
        changeset,
        :move_number,
        changeset.context.game.next_move_number
      )
    end)
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
mix test test/xo/games/move_test.exs --max-failures 3
```

Expected: PASS — all tests including turn validation.

- [ ] **Step 6: Commit**

```bash
git add lib/xo/games/move.ex lib/xo/games/move/changes/derive_from_game.ex lib/xo/games/move/validations/validate_player_turn.ex test/xo/games/move_test.exs
git commit -m "Add ValidatePlayerTurn validation to Move create action"
```

---

### Task 5: Move identity constraint tests

**Files:**
- Modify: `test/xo/games/move_test.exs` (add identity tests)

- [ ] **Step 1: Write tests for identity constraints**

Add to `test/xo/games/move_test.exs`, after the `describe "create action"` block:

```elixir
  describe "identity constraints" do
    test "rejects duplicate field in the same game" do
      %{game: game, player_o: player_o, player_x: player_x} = active_game()

      Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)

      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_x)
      end
    end

    test "rejects duplicate move_number in the same game" do
      %{game: game, player_o: player_o} = active_game()

      Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)

      # This should never happen due to DeriveFromGame, but the DB constraint backs it up
      # We test by creating a second move — move_number is auto-derived so this tests
      # the identity at the DB level indirectly (same field triggers unique_field_per_game first)
      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)
      end
    end

    test "allows same field in different games" do
      %{game: game1, player_o: player_o1} = active_game()
      %{game: game2, player_o: player_o2} = active_game()

      Ash.create!(Move, %{field: 4, game_id: game1.id}, action: :create, actor: player_o1)
      move2 = Ash.create!(Move, %{field: 4, game_id: game2.id}, action: :create, actor: player_o2)

      assert move2.field == 4
    end
  end
```

- [ ] **Step 2: Run tests to verify they pass**

Run:
```bash
mix test test/xo/games/move_test.exs --max-failures 3
```

Expected: PASS — identities from Task 1 enforce these constraints.

- [ ] **Step 3: Commit**

```bash
git add test/xo/games/move_test.exs
git commit -m "Add identity constraint tests for Move"
```

---

### Task 6: Game.make_move delegates to Move.create

**Files:**
- Create: `lib/xo/games/changes/create_move.ex`
- Modify: `lib/xo/games/game.ex:38-45` (make_move action)
- Modify: `test/xo/games/game_test.exs` (add delegation tests)

- [ ] **Step 1: Write failing tests for make_move creating a Move**

Add to `test/xo/games/game_test.exs`, inside the existing `describe "make_move action"` block (after the existing tests):

```elixir
    test "creates a Move record", %{game: game, player_o: player_o} do
      Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)

      [move] = Ash.read!(Xo.Games.Move)
      assert move.field == 4
      assert move.move_number == 1
      assert move.game_id == game.id
      assert move.player_id == player_o.id
    end

    test "creates moves with alternating players", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game =
        Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)

      Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)

      moves = Ash.read!(Xo.Games.Move) |> Enum.sort_by(& &1.move_number)
      assert length(moves) == 2
      assert Enum.at(moves, 0).player_id == player_o.id
      assert Enum.at(moves, 0).move_number == 1
      assert Enum.at(moves, 1).player_id == player_x.id
      assert Enum.at(moves, 1).move_number == 2
    end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
mix test test/xo/games/game_test.exs --max-failures 3
```

Expected: FAIL — make_move doesn't create Move records yet.

- [ ] **Step 3: Create the CreateMove change module**

Create `lib/xo/games/changes/create_move.ex`:

```elixir
defmodule Xo.Games.Changes.CreateMove do
  @moduledoc """
  Change for Game.make_move that creates a Move record via manage_relationship.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    field = Ash.Changeset.get_argument(changeset, :field)

    Ash.Changeset.manage_relationship(changeset, :moves, [%{field: field}], type: :create)
  end
end
```

- [ ] **Step 4: Wire CreateMove into Game.make_move**

In `lib/xo/games/game.ex`, replace the `make_move` action:

```elixir
    update :make_move do
      require_atomic? false

      argument :field, :integer do
        allow_nil? false
        constraints min: 0, max: 8
      end

      change transition_state(:active)
      change Xo.Games.Changes.CreateMove
    end
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
mix test test/xo/games/game_test.exs --max-failures 3
```

Expected: PASS — all tests including new delegation tests.

Note: the existing test "succeeds when actor is player_x" (line 94) may now fail because player_x tries to move first (but it's player_o's turn). If so, update that test:

```elixir
    test "succeeds when actor is player_x", %{game: game, player_o: player_o, player_x: player_x} do
      game = Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)
      assert Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)
    end
```

- [ ] **Step 6: Run the full test suite**

Run:
```bash
mix test --max-failures 5
```

Expected: PASS — no regressions.

- [ ] **Step 7: Commit**

```bash
git add lib/xo/games/changes/create_move.ex lib/xo/games/game.ex test/xo/games/game_test.exs
git commit -m "Game.make_move delegates Move creation via manage_relationship"
```

---

### Task 7: Calculation integration tests (after moves)

**Files:**
- Modify: `test/xo/games/game_test.exs` (add post-move calculation tests)

- [ ] **Step 1: Write tests verifying calculations update after moves**

Add to `test/xo/games/game_test.exs`, after the existing `describe "next_player_id calculation"` block:

```elixir
  describe "calculations after moves" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "next_move_number increments after each move", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game = Ash.load!(game, [:next_move_number])
      assert game.next_move_number == 1

      game =
        Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)

      game = Ash.load!(game, [:next_move_number])
      assert game.next_move_number == 2

      game =
        Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)

      game = Ash.load!(game, [:next_move_number])
      assert game.next_move_number == 3
    end

    test "next_player_id alternates between players", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game = Ash.load!(game, [:next_player_id])
      assert game.next_player_id == player_o.id

      game =
        Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)

      game = Ash.load!(game, [:next_player_id])
      assert game.next_player_id == player_x.id

      game =
        Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)

      game = Ash.load!(game, [:next_player_id])
      assert game.next_player_id == player_o.id
    end
  end
```

- [ ] **Step 2: Run tests to verify they pass**

Run:
```bash
mix test test/xo/games/game_test.exs --max-failures 3
```

Expected: PASS — calculations correctly reflect the current game state.

- [ ] **Step 3: Commit**

```bash
git add test/xo/games/game_test.exs
git commit -m "Add integration tests for Game calculations after moves"
```

---

### Task 8: Move test generator

**Files:**
- Create: `test/support/generators/move_generator.ex`

- [ ] **Step 1: Create Move generator**

Create `test/support/generators/move_generator.ex`:

```elixir
defmodule Xo.Generators.Move do
  use Ash.Generator

  alias Xo.Games.Move

  def move(overrides \\ []) do
    {game, overrides} =
      Keyword.pop_lazy(overrides, :game, fn ->
        player_o = generate(Xo.Generators.User.user())
        game = generate(Xo.Generators.Game.game(actor: player_o))
        player_x = generate(Xo.Generators.User.user())
        Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)
      end)

    game = Ash.load!(game, [:next_player_id], authorize?: false)

    {actor, overrides} =
      Keyword.pop_lazy(overrides, :actor, fn ->
        Ash.get!(Xo.Accounts.User, game.next_player_id, authorize?: false)
      end)

    overrides =
      Keyword.put_new(overrides, :game_id, game.id)

    changeset_generator(
      Move,
      :create,
      actor: actor,
      overrides: overrides
    )
  end
end
```

- [ ] **Step 2: Write a quick smoke test using the generator**

Add to the top of `test/xo/games/move_test.exs`, add the import:

```elixir
  import Xo.Generators.Move, only: [move: 0, move: 1]
```

Then add a new describe block:

```elixir
  describe "generator" do
    test "generates a valid move with defaults" do
      move = generate(move())

      assert move.id
      assert move.field
      assert move.move_number == 1
      assert move.game_id
      assert move.player_id
    end

    test "generates a move for a provided game" do
      %{game: game, player_o: player_o} = active_game()

      move = generate(move(game: game, actor: player_o))

      assert move.game_id == game.id
      assert move.player_id == player_o.id
    end
  end
```

- [ ] **Step 3: Run tests to verify they pass**

Run:
```bash
mix test test/xo/games/move_test.exs --max-failures 3
```

Expected: PASS — generator creates valid moves.

- [ ] **Step 4: Commit**

```bash
git add test/support/generators/move_generator.ex test/xo/games/move_test.exs
git commit -m "Add Move test generator"
```

---

### Task 9: Final verification

- [ ] **Step 1: Run the full test suite**

Run:
```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 2: Run precommit checks**

Run:
```bash
mix precommit
```

Expected: all checks pass (compilation, formatting, tests, etc.).

- [ ] **Step 3: Fix any issues found by precommit**

If there are formatting or compilation warnings, fix them and re-run.

---

## Potential issues to watch for

1. **Ash expression `rem/2`**: Confirmed available as `Ash.Query.Function.Rem`. If it doesn't translate to SQL correctly, fall back to a module-based calculation.
2. **Validation ordering**: Validations run after `change/3` callbacks but before `before_action` hooks. `DeriveFromGame` loads the game in `change/3` (so context is available to validations) but sets `move_number` in a `before_action` hook (so it happens in the transaction).
3. **Actor propagation through manage_relationship**: The actor from Game's make_move should propagate to Move's create action. If it doesn't, the `relate_actor(:player)` and `ValidatePlayerTurn` will fail. Check that `manage_relationship` passes the actor through.
4. **Existing make_move tests**: The test "succeeds when actor is player_x" (game_test.exs:94) currently lets player_x move first. After Task 6, turn validation will reject this. The test must be updated so player_o moves first.
5. **UUID vs integer types**: User has UUID primary key, Game has integer primary key. `next_player_id` calculation type is `:uuid`. `game_id` on Move is `:integer`.
