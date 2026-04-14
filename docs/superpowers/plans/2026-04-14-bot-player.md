# Bot Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add computer player functionality with pluggable strategies that joins games via an Ash action and plays moves autonomously via a GenServer.

**Architecture:** A `Xo.Games.Bot` namespace mirrors the existing Commentator pattern. A behaviour defines the strategy interface, strategies are discoverable as an Ash resource, a GenServer subscribes to game PubSub events and makes moves with a delay, and a `:bot_join` action on Game encapsulates the full flow. Fragments extend Game and Domain without modifying core files.

**Tech Stack:** Elixir, Ash Framework (resources, actions, policies, fragments, code interfaces), Phoenix PubSub, OTP (GenServer, DynamicSupervisor, Registry)

**Spec:** `docs/superpowers/specs/2026-04-14-bot-player-design.md`

---

## File Structure

```
lib/xo/games/bot/
├── behaviour.ex             # Callback definitions for bot strategies
├── strategy.ex              # Ash Resource (Simple data layer) + module registry
├── bot_user.ex              # Bot user creation and persistent_term caching
├── server.ex                # GenServer: subscribes to PubSub, makes moves
├── join_game.ex             # Ash change for :bot_join action
├── game_fragment.ex         # Adds :bot_join action + policy + pub_sub to Game
├── domain_fragment.ex       # Adds Strategy resource + code interfaces to Domain
└── strategies/
    ├── random.ex            # Random field selection
    └── strategic.ex         # Center/corner preference + win/block logic

test/xo/games/bot/
├── strategy_test.exs        # Strategy Ash resource read
├── random_strategy_test.exs # Random strategy unit tests
├── strategic_strategy_test.exs # Strategic strategy unit tests
├── bot_join_test.exs        # :bot_join action tests
└── server_test.exs          # GenServer lifecycle + move-making tests

Modify:
├── lib/xo/application.ex           # Add BotRegistry + BotSupervisor
├── lib/xo/games/game.ex            # Add Bot.GameFragment
├── lib/xo/games.ex                 # Add Bot.DomainFragment
├── lib/xo_web/live/lobby_live.ex   # Add bot_join_game event handler
├── lib/xo_web/components/lobby_components.ex  # Add bot join dropdown UI
├── config/config.exs               # Add bot config
```

---

### Task 1: Behaviour and Random Strategy

**Files:**
- Create: `lib/xo/games/bot/behaviour.ex`
- Create: `lib/xo/games/bot/strategies/random.ex`
- Create: `test/xo/games/bot/random_strategy_test.exs`

- [ ] **Step 1: Write the behaviour module**

```elixir
# lib/xo/games/bot/behaviour.ex
defmodule Xo.Games.Bot.Behaviour do
  @moduledoc "Defines the contract that all bot strategies must implement."

  @callback info() :: %{key: atom(), name: String.t(), description: String.t()}
  @callback bot_email() :: String.t()
  @callback select_move(game :: Ash.Resource.record()) :: {:ok, non_neg_integer()}
end
```

- [ ] **Step 2: Write the failing test for Random strategy**

```elixir
# test/xo/games/bot/random_strategy_test.exs
defmodule Xo.Games.Bot.Strategies.RandomTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games.Bot.Strategies.Random

  describe "info/0" do
    test "returns strategy metadata" do
      info = Random.info()

      assert info.key == :random
      assert is_binary(info.name)
      assert is_binary(info.description)
    end
  end

  describe "bot_email/0" do
    test "returns a bot email" do
      assert Random.bot_email() == "random-bot@xo.bot"
    end
  end

  describe "select_move/1" do
    test "returns an available field" do
      player_o = generate(user())
      player_x = generate(user())

      game =
        generate(game(actor: player_o))
        |> Ash.update!(%{}, action: :join, actor: player_x, authorize?: true)

      {:ok, field} = Random.select_move(game)

      assert field in 0..8
    end

    test "returns a field not already taken" do
      player_o = generate(user())
      player_x = generate(user())

      game =
        generate(game(actor: player_o))
        |> Ash.update!(%{}, action: :join, actor: player_x, authorize?: true)

      # O plays center
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Random.select_move(game)

      available = Ash.load!(game, :available_fields).available_fields
      assert field in available
      refute field == 4
    end
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `mix test test/xo/games/bot/random_strategy_test.exs --max-failures 1`
Expected: Compilation error — `Xo.Games.Bot.Strategies.Random` not found

- [ ] **Step 4: Implement Random strategy**

```elixir
# lib/xo/games/bot/strategies/random.ex
defmodule Xo.Games.Bot.Strategies.Random do
  @moduledoc "Bot strategy that selects a random available field."

  @behaviour Xo.Games.Bot.Behaviour

  @impl true
  def info do
    %{key: :random, name: "Random Bot", description: "Picks a random available field."}
  end

  @impl true
  def bot_email, do: "random-bot@xo.bot"

  @impl true
  def select_move(game) do
    game = Ash.load!(game, [:available_fields])
    {:ok, Enum.random(game.available_fields)}
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/xo/games/bot/random_strategy_test.exs`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
jj describe -m "Add bot behaviour and random strategy"
jj new
```

---

### Task 2: Strategic Strategy

**Files:**
- Create: `lib/xo/games/bot/strategies/strategic.ex`
- Create: `test/xo/games/bot/strategic_strategy_test.exs`

- [ ] **Step 1: Write failing tests for Strategic strategy**

```elixir
# test/xo/games/bot/strategic_strategy_test.exs
defmodule Xo.Games.Bot.Strategies.StrategicTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games.Bot.Strategies.Strategic

  describe "info/0" do
    test "returns strategy metadata" do
      info = Strategic.info()

      assert info.key == :strategic
      assert is_binary(info.name)
      assert is_binary(info.description)
    end
  end

  describe "bot_email/0" do
    test "returns a bot email" do
      assert Strategic.bot_email() == "strategic-bot@xo.bot"
    end
  end

  describe "select_move/1" do
    setup do
      player_o = generate(user())
      player_x = generate(user())

      game =
        generate(game(actor: player_o))
        |> Ash.update!(%{}, action: :join, actor: player_x, authorize?: true)

      %{game: game, player_o: player_o, player_x: player_x}
    end

    test "prefers center on empty board", %{game: game} do
      {:ok, field} = Strategic.select_move(game)

      assert field == 4
    end

    test "takes winning move when available", %{game: game, player_o: player_o, player_x: player_x} do
      # Bot is player_x. Set up: X has 0 and 1, field 2 wins.
      # O: 4, 3; X: 0, 1
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 0}, action: :make_move, actor: player_x, authorize?: true)
      game = Ash.update!(game, %{field: 3}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)

      # Now it's O's turn, but we test strategic logic from X's perspective
      # Let O move to a non-threatening spot
      game = Ash.update!(game, %{field: 8}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Strategic.select_move(game)

      # X should complete the top row: [0, 1, 2]
      assert field == 2
    end

    test "blocks opponent winning move", %{game: game, player_o: player_o, player_x: player_x} do
      # O has 0 and 1, about to win with 2. X should block.
      # O: 0, 1; X: 4
      game = Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_x, authorize?: true)
      game = Ash.update!(game, %{field: 1}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Strategic.select_move(game)

      # X should block position 2
      assert field == 2
    end

    test "prefers corner when center is taken", %{game: game, player_o: player_o, player_x: player_x} do
      # O takes center, X should take a corner
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Strategic.select_move(game)

      assert field in [0, 2, 6, 8]
    end

    test "falls back to edge when center and corners taken", %{game: game, player_o: player_o, player_x: player_x} do
      # Fill center and all corners, leave only edges
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 0}, action: :make_move, actor: player_x, authorize?: true)
      game = Ash.update!(game, %{field: 8}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 2}, action: :make_move, actor: player_x, authorize?: true)
      game = Ash.update!(game, %{field: 6}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Strategic.select_move(game)

      assert field in [1, 3, 5, 7]
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/xo/games/bot/strategic_strategy_test.exs --max-failures 1`
Expected: Compilation error — `Xo.Games.Bot.Strategies.Strategic` not found

- [ ] **Step 3: Implement Strategic strategy**

```elixir
# lib/xo/games/bot/strategies/strategic.ex
defmodule Xo.Games.Bot.Strategies.Strategic do
  @moduledoc "Bot strategy that prefers center/corners and blocks opponent wins."

  @behaviour Xo.Games.Bot.Behaviour

  @corners [0, 2, 6, 8]
  @edges [1, 3, 5, 7]

  @impl true
  def info do
    %{
      key: :strategic,
      name: "Strategic Bot",
      description: "Prefers center and corners. Blocks and takes winning moves."
    }
  end

  @impl true
  def bot_email, do: "strategic-bot@xo.bot"

  @impl true
  def select_move(game) do
    game = Ash.load!(game, [:available_fields, :player_o_fields, :player_x_fields, :player_o_id])

    bot_fields = game.player_x_fields
    opponent_fields = game.player_o_fields
    available = game.available_fields

    field =
      find_winning_move(bot_fields, available) ||
        find_winning_move(opponent_fields, available) ||
        try_center(available) ||
        try_corners(available) ||
        try_edges(available)

    {:ok, field}
  end

  defp find_winning_move(player_fields, available) do
    Xo.Games.WinChecker.winning_combinations()
    |> Enum.find_value(fn combo ->
      in_combo = Enum.filter(combo, &(&1 in player_fields))
      open_in_combo = Enum.filter(combo, &(&1 in available))

      if length(in_combo) == 2 && length(open_in_combo) == 1 do
        hd(open_in_combo)
      end
    end)
  end

  defp try_center(available) do
    if 4 in available, do: 4
  end

  defp try_corners(available) do
    case Enum.filter(@corners, &(&1 in available)) do
      [] -> nil
      corners -> Enum.random(corners)
    end
  end

  defp try_edges(available) do
    case Enum.filter(@edges, &(&1 in available)) do
      [] -> nil
      edges -> Enum.random(edges)
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/xo/games/bot/strategic_strategy_test.exs`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
jj describe -m "Add strategic bot strategy"
jj new
```

---

### Task 3: Strategy Ash Resource and Domain Fragment

**Files:**
- Create: `lib/xo/games/bot/strategy.ex`
- Create: `lib/xo/games/bot/domain_fragment.ex`
- Modify: `lib/xo/games.ex` — add `fragments: [Xo.Games.Bot.DomainFragment]`
- Create: `test/xo/games/bot/strategy_test.exs`

- [ ] **Step 1: Write failing test for Strategy resource**

```elixir
# test/xo/games/bot/strategy_test.exs
defmodule Xo.Games.Bot.StrategyTest do
  use Xo.DataCase, async: true

  alias Xo.Games

  describe "list_strategies" do
    test "returns all available strategies" do
      strategies = Games.list_strategies!()

      assert length(strategies) == 2
      keys = Enum.map(strategies, & &1.key) |> Enum.sort()
      assert keys == [:random, :strategic]
    end

    test "each strategy has name and description" do
      strategies = Games.list_strategies!()

      for strategy <- strategies do
        assert is_binary(strategy.name)
        assert is_binary(strategy.description)
      end
    end
  end

  describe "module_for!/1" do
    test "returns module for :random" do
      assert Xo.Games.Bot.Strategy.module_for!(:random) == Xo.Games.Bot.Strategies.Random
    end

    test "returns module for :strategic" do
      assert Xo.Games.Bot.Strategy.module_for!(:strategic) == Xo.Games.Bot.Strategies.Strategic
    end

    test "raises for unknown strategy" do
      assert_raise KeyError, fn ->
        Xo.Games.Bot.Strategy.module_for!(:nonexistent)
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/xo/games/bot/strategy_test.exs --max-failures 1`
Expected: Compilation error — modules not found

- [ ] **Step 3: Implement Strategy resource**

```elixir
# lib/xo/games/bot/strategy.ex
defmodule Xo.Games.Bot.Strategy do
  @moduledoc "Ash resource representing available bot strategies."

  use Ash.Resource,
    otp_app: :xo,
    domain: Xo.Games,
    data_layer: Ash.DataLayer.Simple

  @modules %{
    random: Xo.Games.Bot.Strategies.Random,
    strategic: Xo.Games.Bot.Strategies.Strategic
  }

  def all_modules, do: Map.values(@modules)

  def module_for!(key), do: Map.fetch!(@modules, key)

  attributes do
    attribute :key, :atom, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
  end

  actions do
    read :read do
      manual fn _, _, _ ->
        strategies =
          for module <- all_modules() do
            info = module.info()
            struct!(__MODULE__, info)
          end

        {:ok, strategies}
      end
    end
  end
end
```

- [ ] **Step 4: Implement Domain Fragment**

```elixir
# lib/xo/games/bot/domain_fragment.ex
defmodule Xo.Games.Bot.DomainFragment do
  use Spark.Dsl.Fragment,
    of: Ash.Domain

  resources do
    resource Xo.Games.Bot.Strategy do
      define :list_strategies, action: :read
    end
  end
end
```

- [ ] **Step 5: Add fragment to Domain**

Modify `lib/xo/games.ex` — add the Bot.DomainFragment to the `use Ash.Domain` call:

```elixir
# Change from:
  use Ash.Domain,
    otp_app: :xo,
    extensions: [AshPhoenix],
    fragments: [Xo.Games.Commentator.DomainFragment]

# Change to:
  use Ash.Domain,
    otp_app: :xo,
    extensions: [AshPhoenix],
    fragments: [Xo.Games.Commentator.DomainFragment, Xo.Games.Bot.DomainFragment]
```

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/xo/games/bot/strategy_test.exs`
Expected: All tests pass

- [ ] **Step 7: Commit**

```bash
jj describe -m "Add Strategy Ash resource and domain fragment"
jj new
```

---

### Task 4: BotUser Module

**Files:**
- Create: `lib/xo/games/bot/bot_user.ex`

- [ ] **Step 1: Implement BotUser**

```elixir
# lib/xo/games/bot/bot_user.ex
defmodule Xo.Games.Bot.BotUser do
  @moduledoc "Manages bot user accounts, one per strategy. Cached in persistent_term."

  require Ash.Query

  def user(strategy_module) do
    key = persistent_term_key(strategy_module)

    case :persistent_term.get(key, nil) do
      nil -> ensure_user(strategy_module, key)
      user -> user
    end
  end

  defp ensure_user(strategy_module, key) do
    email = strategy_module.bot_email()
    name = strategy_module.info().name

    user =
      case Xo.Accounts.User
           |> Ash.Query.filter(email == ^email)
           |> Ash.read_one!(authorize?: false) do
        nil ->
          Xo.Accounts.demo_create_user!(name, email)

        existing ->
          existing
      end

    :persistent_term.put(key, user)
    user
  end

  defp persistent_term_key(strategy_module) do
    {:bot_user, strategy_module}
  end
end
```

- [ ] **Step 2: Verify it compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors

- [ ] **Step 3: Commit**

```bash
jj describe -m "Add BotUser module for strategy-specific bot accounts"
jj new
```

---

### Task 5: Bot Join Action (GameFragment + JoinGame Change)

**Files:**
- Create: `lib/xo/games/bot/join_game.ex`
- Create: `lib/xo/games/bot/game_fragment.ex`
- Modify: `lib/xo/games.ex` — add `bot_join` code interface to DomainFragment
- Modify: `lib/xo/games/game.ex` — add `Bot.GameFragment` to fragments
- Modify: `lib/xo/application.ex` — add BotRegistry + BotSupervisor
- Modify: `config/config.exs` — add bot config
- Create: `test/xo/games/bot/bot_join_test.exs`

- [ ] **Step 1: Add supervision tree entries**

Modify `lib/xo/application.ex` — add after the Commentator supervision entries:

```elixir
      {Registry, keys: :unique, name: Xo.Games.BotRegistry},
      {DynamicSupervisor, name: Xo.Games.BotSupervisor, strategy: :one_for_one},
```

- [ ] **Step 2: Add bot config**

Modify `config/config.exs` — add near the end (before `import_config`):

```elixir
# Bot player
config :xo, :bot_enabled, true
config :xo, :bot_delay_ms, 1_000
```

- [ ] **Step 3: Write failing tests for bot_join action**

```elixir
# test/xo/games/bot/bot_join_test.exs
defmodule Xo.Games.Bot.BotJoinTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games

  describe "bot_join" do
    test "bot joins as player_x" do
      player_o = generate(user())
      game = generate(game(actor: player_o))

      game = Games.bot_join!(game, :random, actor: player_o, load: [:state, :player_x])

      assert game.state == :active
      assert game.player_x.email == "random-bot@xo.bot"
    end

    test "works with strategic strategy" do
      player_o = generate(user())
      game = generate(game(actor: player_o))

      game = Games.bot_join!(game, :strategic, actor: player_o, load: [:player_x])

      assert game.player_x.email == "strategic-bot@xo.bot"
    end

    test "fails when game is not open" do
      player_o = generate(user())
      player_x = generate(user())

      game =
        generate(game(actor: player_o))
        |> Ash.update!(%{}, action: :join, actor: player_x, authorize?: true)

      assert_raise Ash.Error.Invalid, fn ->
        Games.bot_join!(game, :random, actor: player_o)
      end
    end

    test "fails when actor is not the game creator" do
      player_o = generate(user())
      stranger = generate(user())
      game = generate(game(actor: player_o))

      assert_raise Ash.Error.Forbidden, fn ->
        Games.bot_join!(game, :random, actor: stranger)
      end
    end

    test "fails without an actor" do
      player_o = generate(user())
      game = generate(game(actor: player_o))

      assert_raise Ash.Error.Forbidden, fn ->
        Games.bot_join!(game, :random, authorize?: true)
      end
    end

    test "starts a Bot.Server process" do
      player_o = generate(user())
      game = generate(game(actor: player_o))

      game = Games.bot_join!(game, :random, actor: player_o)

      assert [{pid, _}] = Registry.lookup(Xo.Games.BotRegistry, game.id)
      assert Process.alive?(pid)
    end
  end
end
```

- [ ] **Step 4: Run test to verify it fails**

Run: `mix test test/xo/games/bot/bot_join_test.exs --max-failures 1`
Expected: Failure — `bot_join` function not defined

- [ ] **Step 5: Implement JoinGame change**

```elixir
# lib/xo/games/bot/join_game.ex
defmodule Xo.Games.Bot.JoinGame do
  @moduledoc "Ash change that joins a bot as player_x and starts the Bot.Server."

  use Ash.Resource.Change
  require Logger

  alias Xo.Games.Bot.{BotUser, Strategy}

  @impl true
  def change(changeset, _opts, _context) do
    strategy_key = Ash.Changeset.get_argument(changeset, :strategy)
    strategy_module = Strategy.module_for!(strategy_key)
    bot_user = BotUser.user(strategy_module)

    changeset
    |> Ash.Changeset.manage_relationship(:player_x, bot_user, type: :append_and_remove)
    |> Ash.Changeset.after_action(fn _changeset, game ->
      if Application.get_env(:xo, :bot_enabled, true) do
        case DynamicSupervisor.start_child(
               Xo.Games.BotSupervisor,
               {Xo.Games.Bot.Server, {game.id, strategy_module}}
             ) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to start bot for game #{game.id}: #{inspect(reason)}")
        end
      end

      {:ok, game}
    end)
  end
end
```

- [ ] **Step 6: Implement GameFragment**

```elixir
# lib/xo/games/bot/game_fragment.ex
defmodule Xo.Games.Bot.GameFragment do
  use Spark.Dsl.Fragment,
    of: Ash.Resource,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias Xo.Games.Validations.ValidateGameState

  actions do
    update :bot_join do
      description "Have a computer player join an open game."
      require_atomic? false

      argument :strategy, :atom do
        description "The bot strategy key (e.g. :random, :strategic)."
        allow_nil? false
      end

      validate {ValidateGameState, states: [:open]}
      change Xo.Games.Bot.JoinGame
      change Xo.Games.Commentator.StartCommentator
    end
  end

  policies do
    policy action(:bot_join) do
      description "The game creator can invite a bot to join."
      forbid_unless actor_present()
      authorize_if expr(player_o_id == ^actor(:id))
    end
  end

  pub_sub do
    publish :bot_join, ["activity", :_pkey]
    publish :bot_join, [:_pkey], load: [:state, :board, :player_o, :player_x, :next_player_id]
    publish :bot_join, "lobby"
  end
end
```

- [ ] **Step 7: Add bot_join to DomainFragment code interfaces**

Modify `lib/xo/games/bot/domain_fragment.ex` — add the Game resource with bot_join interface:

```elixir
# lib/xo/games/bot/domain_fragment.ex
defmodule Xo.Games.Bot.DomainFragment do
  use Spark.Dsl.Fragment,
    of: Ash.Domain

  resources do
    resource Xo.Games.Bot.Strategy do
      define :list_strategies, action: :read
    end

    resource Xo.Games.Game do
      define :bot_join, action: :bot_join, args: [:strategy]
    end
  end
end
```

- [ ] **Step 8: Add GameFragment to Game resource**

Modify `lib/xo/games/game.ex` — add `Xo.Games.Bot.GameFragment` to fragments:

```elixir
# Change from:
  use Ash.Resource,
    otp_app: :xo,
    domain: Xo.Games,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    fragments: [Xo.Games.Commentator.GameFragment]

# Change to:
  use Ash.Resource,
    otp_app: :xo,
    domain: Xo.Games,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    fragments: [Xo.Games.Commentator.GameFragment, Xo.Games.Bot.GameFragment]
```

- [ ] **Step 9: Run test to verify it passes**

Run: `mix test test/xo/games/bot/bot_join_test.exs`
Expected: All tests pass (the "starts a Bot.Server process" test will fail because Server doesn't exist yet — mark it `@tag :skip` for now)

Note: If the "starts a Bot.Server process" test fails because `Xo.Games.Bot.Server` doesn't exist, temporarily tag it with `@tag :skip` and add `@describetag :skip` or skip that single test. It will be unskipped in Task 6.

- [ ] **Step 10: Commit**

```bash
jj describe -m "Add bot_join action with GameFragment and JoinGame change"
jj new
```

---

### Task 6: Bot GenServer

**Files:**
- Create: `lib/xo/games/bot/server.ex`
- Create: `test/xo/games/bot/server_test.exs`

- [ ] **Step 1: Write failing tests for Bot.Server**

```elixir
# test/xo/games/bot/server_test.exs
defmodule Xo.Games.Bot.ServerTest do
  use Xo.DataCase, async: false

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games
  alias Xo.Games.Bot.Server

  setup do
    player_o = generate(user())
    game = generate(game(actor: player_o))

    # Use bot_join to set up the game with a bot and start the server
    game = Games.bot_join!(game, :random, actor: player_o)

    %{game: game, player_o: player_o}
  end

  describe "lifecycle" do
    test "server is registered after bot_join", %{game: game} do
      assert [{pid, _}] = Registry.lookup(Xo.Games.BotRegistry, game.id)
      assert Process.alive?(pid)
    end

    test "server stops after game is won", %{game: game, player_o: player_o} do
      [{pid, _}] = Registry.lookup(Xo.Games.BotRegistry, game.id)
      ref = Process.monitor(pid)

      # Play a quick game where O wins: O takes 0, 1, 2 (top row)
      # After each O move, the bot will respond. We need to play around that.
      game = Games.make_move!(game, 0, actor: player_o, load: [:state, :next_player_id])

      # Wait for bot to make its move
      Process.sleep(1_500)

      game = Games.get_by_id!(game.id, load: [:state, :next_player_id, :available_fields])

      if game.state == :active do
        game = Games.make_move!(game, 1, actor: player_o, load: [:state])
        Process.sleep(1_500)
        game = Games.get_by_id!(game.id, load: [:state, :next_player_id])

        if game.state == :active do
          Games.make_move!(game, 2, actor: player_o)
          Process.sleep(1_500)
        end
      end

      # Server should eventually stop
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000
    end

    test "server stops when game is destroyed", %{game: game} do
      [{pid, _}] = Registry.lookup(Xo.Games.BotRegistry, game.id)
      ref = Process.monitor(pid)

      Ash.destroy!(game, authorize?: false)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000
    end
  end

  describe "move making" do
    test "bot makes a move after human moves", %{game: game, player_o: player_o} do
      Games.make_move!(game, 4, actor: player_o)

      # Wait for bot delay + processing
      Process.sleep(2_000)

      game = Games.get_by_id!(game.id, load: [:move_count])

      # Bot should have made a response move
      assert game.move_count == 2
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/xo/games/bot/server_test.exs --max-failures 1`
Expected: Failure — `Xo.Games.Bot.Server` not found

- [ ] **Step 3: Implement Bot.Server**

```elixir
# lib/xo/games/bot/server.ex
defmodule Xo.Games.Bot.Server do
  @moduledoc "Per-game GenServer that subscribes to game events and makes moves for a bot player."

  use GenServer
  require Logger

  alias Xo.Games

  def start_link({game_id, strategy_module}) do
    GenServer.start_link(__MODULE__, {game_id, strategy_module}, name: via(game_id))
  end

  def via(game_id) do
    {:via, Registry, {Xo.Games.BotRegistry, game_id}}
  end

  @impl true
  def init({game_id, strategy_module}) do
    Phoenix.PubSub.subscribe(Xo.PubSub, "game:#{game_id}")
    bot_user = Xo.Games.Bot.BotUser.user(strategy_module)
    delay_ms = Application.get_env(:xo, :bot_delay_ms, 1_000)

    {:ok,
     %{
       game_id: game_id,
       bot_user: bot_user,
       strategy: strategy_module,
       delay_ms: delay_ms
     }}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event} = broadcast, state) do
    case classify_event(event, broadcast.payload, state.bot_user.id) do
      {:move, game} ->
        schedule_move(game, state)
        {:noreply, state}

      :game_over ->
        Process.send_after(self(), :shutdown, 2_000)
        {:noreply, state}

      :abandoned ->
        {:stop, :normal, state}

      :ignore ->
        {:noreply, state}
    end
  end

  def handle_info({:execute_move, game}, state) do
    try do
      {:ok, field} = state.strategy.select_move(game)
      Games.make_move!(game, field, actor: state.bot_user)
    rescue
      e ->
        Logger.error(
          "Bot failed to make move in game #{state.game_id}: #{Exception.message(e)}"
        )
    end

    {:noreply, state}
  end

  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  defp classify_event("make_move", %{data: game}, bot_user_id) do
    case game.state do
      :won -> :game_over
      :draw -> :game_over
      :active when game.next_player_id == bot_user_id -> {:move, game}
      _ -> :ignore
    end
  end

  defp classify_event("destroy", _payload, _bot_user_id) do
    :abandoned
  end

  defp classify_event(_event, _payload, _bot_user_id), do: :ignore

  defp schedule_move(game, state) do
    Process.send_after(self(), {:execute_move, game}, state.delay_ms)
  end
end
```

- [ ] **Step 4: Unskip the bot_join test if skipped in Task 5**

If you tagged the "starts a Bot.Server process" test in `test/xo/games/bot/bot_join_test.exs` with `@tag :skip`, remove that tag now.

- [ ] **Step 5: Run all bot tests**

Run: `mix test test/xo/games/bot/`
Expected: All tests pass

- [ ] **Step 6: Run the full test suite**

Run: `mix test`
Expected: All tests pass (existing tests unaffected)

- [ ] **Step 7: Commit**

```bash
jj describe -m "Add Bot.Server GenServer for autonomous move making"
jj new
```

---

### Task 7: Lobby UI Integration

**Files:**
- Modify: `lib/xo_web/live/lobby_live.ex` — add `bot_join_game` event handler
- Modify: `lib/xo_web/components/lobby_components.ex` — add bot join dropdown

- [ ] **Step 1: Add bot_join_game event handler to LobbyLive**

Modify `lib/xo_web/live/lobby_live.ex` — add after the `handle_event("join_game", ...)` function:

```elixir
  def handle_event("bot_join_game", %{"game-id" => game_id, "strategy" => strategy}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, put_flash(socket, :error, "You must be signed in")}

      user ->
        game = Games.get_by_id!(game_id)
        strategy = String.to_existing_atom(strategy)
        Games.bot_join!(game, strategy, actor: user)
        {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
    end
  end
```

Also add a `load_strategies` call in `mount/1`. Modify the `mount` function to also assign strategies:

```elixir
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xo.PubSub, "game:lobby")
    end

    socket =
      socket
      |> assign(:page_title, "Lobby")
      |> assign(:strategies, Games.list_strategies!())
      |> load_games()

    {:ok, socket}
  end
```

- [ ] **Step 2: Add bot join dropdown to lobby card**

Modify `lib/xo_web/components/lobby_components.ex` — add a `strategies` attr to `card_action` and update the game owner's card action.

First, add `strategies` as an attr to `game_card` and pass it through:

Replace the `game_card` component:

```elixir
  attr :game, :any, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true
  attr :strategies, :list, default: []

  def game_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 rounded-xl">
      <div class="card-body p-4 flex-row items-center justify-between">
        <div class="flex items-center gap-3">
          <.game_state_badge state={@game.state} />
          <div>
            <span class="font-semibold">{creator_name(@game)}</span>
            <span :if={@variant == :active && @game.player_x} class="text-base-content/50">
              vs {@game.player_x.name}
            </span>
            <span :if={@game.move_count > 0} class="text-sm text-base-content/40 ml-2">
              · {@game.move_count} moves
            </span>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <.card_action game={@game} current_user={@current_user} variant={@variant} strategies={@strategies} />
        </div>
      </div>
    </div>
    """
  end
```

Update `games_list` to accept and pass `strategies`:

```elixir
  attr :games, :list, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true
  attr :strategies, :list, default: []

  def games_list(assigns) do
    ~H"""
    <div class="grid gap-4">
      <.game_card :for={game <- @games} game={game} current_user={@current_user} variant={@variant} strategies={@strategies} />
    </div>
    """
  end
```

Add `strategies` attr to `card_action`:

```elixir
  attr :game, :any, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true
  attr :strategies, :list, default: []
```

Update the game-owner clause of `card_action` (when variant is `:open` and user is the game creator):

```elixir
  defp card_action(%{variant: :open, current_user: user, game: game} = assigns) do
    if user.id == game.player_o_id do
      ~H"""
      <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost rounded-lg">
        Open
      </.link>
      <div class="dropdown dropdown-end">
        <div tabindex="0" role="button" class="btn btn-sm btn-secondary rounded-lg">
          Bot Join ▾
        </div>
        <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
          <li :for={strategy <- @strategies}>
            <button
              phx-click="bot_join_game"
              phx-value-game-id={@game.id}
              phx-value-strategy={strategy.key}
            >
              {strategy.name}
            </button>
          </li>
        </ul>
      </div>
      """
    else
      ~H"""
      <button
        phx-click="join_game"
        phx-value-game-id={@game.id}
        class="btn btn-sm btn-primary rounded-lg"
      >
        Join
      </button>
      """
    end
  end
```

- [ ] **Step 3: Update lobby render to pass strategies**

Modify the `render/1` in `lobby_live.ex` — pass `strategies` to `games_list`:

```elixir
        <.games_list games={@open_games} current_user={@current_user} variant={:open} strategies={@strategies} />
```

- [ ] **Step 4: Verify compilation and manual test**

Run: `mix compile --warnings-as-errors`
Expected: Compiles without errors

- [ ] **Step 5: Run all tests**

Run: `mix test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
jj describe -m "Add bot join dropdown to lobby UI"
jj new
```

---

### Task 8: Integration Test — Full Bot Game

**Files:**
- Modify: `test/xo/games/bot/server_test.exs` — add integration test

- [ ] **Step 1: Add a full game integration test**

Add to `test/xo/games/bot/server_test.exs`:

```elixir
  describe "full game integration" do
    test "bot plays a complete game to conclusion", %{game: game, player_o: player_o} do
      # Play as O, making moves and letting the bot respond
      # O plays: 0, then waits for bot, then 1, waits, then 2 (top row win attempt)
      game = Games.make_move!(game, 0, actor: player_o)
      Process.sleep(2_000)

      game = Games.get_by_id!(game.id, load: [:state, :move_count, :next_player_id, :available_fields])

      if game.state == :active do
        game = Games.make_move!(game, 1, actor: player_o)
        Process.sleep(2_000)

        game = Games.get_by_id!(game.id, load: [:state, :move_count, :next_player_id, :available_fields])

        if game.state == :active do
          game = Games.make_move!(game, 2, actor: player_o)
          Process.sleep(2_000)

          game = Games.get_by_id!(game.id, load: [:state, :move_count])
        end
      end

      # Game should have concluded (won or draw) or still be active with multiple moves
      assert game.move_count >= 3
    end
  end
```

- [ ] **Step 2: Run the integration test**

Run: `mix test test/xo/games/bot/server_test.exs`
Expected: All tests pass

- [ ] **Step 3: Run the full test suite one final time**

Run: `mix test`
Expected: All tests pass, no regressions

- [ ] **Step 4: Commit**

```bash
jj describe -m "Add bot player integration test"
jj new
```
