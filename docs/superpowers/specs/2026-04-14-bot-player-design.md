# Bot Player Design

## Summary

Add computer player functionality to the XO game. A bot joins as player_x via a domain-level Ash action, plays moves autonomously via a GenServer that subscribes to game PubSub events, and uses pluggable strategies defined through a behaviour. The system mirrors the existing Commentator architecture.

## Requirements

- A human player can invite a bot to join their open game from the lobby UI
- The bot always plays as player_x (the joiner)
- Different bot strategies are pluggable via a behaviour
- Strategies are discoverable as an Ash resource (any UI can query available bots)
- The bot makes moves with a configurable delay for natural game flow
- The bot coexists with the Commentator in the same game
- One bot user per strategy, identified by name and email

## Architecture

### Behaviour: `Xo.Games.Bot.Behaviour`

Defines the contract that all bot strategies must implement:

```elixir
@callback info() :: %{key: atom(), name: String.t(), description: String.t()}
@callback bot_email() :: String.t()
@callback select_move(game :: Ash.Resource.record()) :: {:ok, field :: non_neg_integer()}
```

- `info/0` — metadata used to populate the Strategy Ash resource
- `bot_email/0` — unique email for the bot user associated with this strategy
- `select_move/1` — receives the game struct as-is; the strategy can call `Ash.load!/2` to load any calculations it needs (e.g. `available_fields`, `board`). Returns the chosen board position (0-8).

### Ash Resource: `Xo.Games.Bot.Strategy`

An Ash resource backed by `Ash.DataLayer.Simple` that makes available strategies discoverable:

```elixir
attributes do
  attribute :key, :atom, primary_key?: true, public?: true
  attribute :name, :string, allow_nil?: false, public?: true
  attribute :description, :string, public?: true
end

actions do
  read :read do
    manual fn _, _, _ ->
      strategies =
        for module <- Xo.Games.Bot.Strategy.all_modules() do
          struct!(__MODULE__, module.info())
        end
      {:ok, strategies}
    end
  end
end
```

`all_modules/0` returns the list of known strategy modules. `module_for!/1` maps a strategy key atom to its module.

### GenServer: `Xo.Games.Bot.Server`

A per-game GenServer that subscribes to game events and makes moves on behalf of the bot.

**State:**
```elixir
%{game_id: integer, bot_user: User.t(), strategy: module(), delay_ms: non_neg_integer()}
```

**Lifecycle:**

1. Started via `DynamicSupervisor` from the `Bot.JoinGame` Ash change (after the bot joins the game)
2. Named via Registry: `{:via, Registry, {Xo.Games.BotRegistry, game_id}}`
3. On `init/1`: Receives `{game_id, strategy_module}`. Subscribes to `"game:#{game_id}"`
4. On `handle_info` for `"make_move"` broadcast:
   - Game state `:active` and `next_player_id` matches bot → call `strategy.select_move/1`, schedule move after delay
   - Game state `:won` or `:draw` → schedule shutdown
   - Otherwise → ignore
5. On delayed `:execute_move` message: calls `Games.make_move!/2` with chosen field, bot user as actor
6. On `"destroy"` event → stop immediately

**Default delay:** 1000ms, configurable via application env `config :xo, :bot_delay_ms, 1_000`.

**Note:** Player O always moves first. After bot joins as player_x, it waits for the first `"make_move"` PubSub event (O's move) before responding. No special first-move handling needed.

### Ash Change: `Xo.Games.Bot.JoinGame`

Runs as part of the `:bot_join` action on Game:

1. Resolves the `:strategy` argument atom to a strategy module via `Strategy.module_for!/1`
2. Gets or creates the bot user for that strategy via `Bot.BotUser.user/1`
3. Sets `player_x` relationship to the bot user on the changeset
4. In an `after_action` callback, starts the `Bot.Server` via `DynamicSupervisor`

### Ash Action: `:bot_join` on Game

```elixir
update :bot_join do
  description "Have a computer player join an open game."
  require_atomic? false

  argument :strategy, :atom do
    description "The bot strategy key (e.g. :random, :strategic)."
    allow_nil? false
  end

  validate {ValidateGameState, states: [:open]}
  change Bot.JoinGame
  change Xo.Games.Commentator.StartCommentator
end
```

The Commentator is started here too so both systems run for bot games.

**Policy:**

```elixir
policy action(:bot_join) do
  description "The game creator can invite a bot to join."
  forbid_unless actor_present()
  authorize_if expr(player_o_id == ^actor(:id))
end
```

The actor is the human player who owns the game, not the bot.

### Bot User Management: `Xo.Games.Bot.BotUser`

Similar to `Xo.Games.Commentator.Bot`:

- Takes a strategy module, calls `strategy.bot_email/0` to get the email
- Creates the user if it doesn't exist (using `Xo.Accounts.demo_create_user!/2`)
- Caches in `persistent_term` keyed by strategy module
- Bot name is derived from `strategy.info().name`

### Fragments

**`Xo.Games.Bot.GameFragment`** — adds to `Xo.Games.Game`:
- The `:bot_join` action
- The `:bot_join` policy

**`Xo.Games.Bot.DomainFragment`** — adds to `Xo.Games`:
- The `Bot.Strategy` resource with `define :list_strategies, action: :read`
- The `bot_join` code interface: `define :bot_join, action: :bot_join, args: [:strategy]`

### PubSub

The `:bot_join` action should publish to the same topics as `:join`:
- `"game:activity:#{id}"`
- `"game:#{id}"` (with state, board, players loaded)
- `"game:lobby"`

This ensures the lobby and game LiveViews update correctly when a bot joins.

## Strategies

### `Xo.Games.Bot.Strategies.Random`

- Loads `available_fields` on the game
- Returns `Enum.random(available_fields)`

### `Xo.Games.Bot.Strategies.Strategic`

- Loads `board`, `available_fields`, `player_o_fields`, `player_x_fields`
- Priority order:
  1. **Win:** If bot has two in a winning line with the third available, take it
  2. **Block:** If opponent has two in a winning line with the third available, block it
  3. **Center:** Take position 4 if available
  4. **Corners:** Take an available corner (0, 2, 6, 8)
  5. **Edges:** Take an available edge (1, 3, 5, 7)
- Can reuse `Xo.Games.WinChecker` winning combinations for win/block detection

## File Structure

```
lib/xo/games/bot/
├── behaviour.ex             # @callback definitions
├── strategy.ex              # Ash Resource (Simple data layer)
├── bot_user.ex              # Bot user creation and caching
├── server.ex                # GenServer
├── join_game.ex             # Ash change for :bot_join
├── game_fragment.ex         # Adds :bot_join action + policy to Game
├── domain_fragment.ex       # Adds Strategy resource + code interfaces to Domain
└── strategies/
    ├── random.ex
    └── strategic.ex
```

## Supervision

Added to `Xo.Application` alongside Commentator entries:

```elixir
{Registry, keys: :unique, name: Xo.Games.BotRegistry},
{DynamicSupervisor, name: Xo.Games.BotSupervisor, strategy: :one_for_one},
```

## Configuration

```elixir
config :xo, :bot_enabled, true        # Kill switch
config :xo, :bot_delay_ms, 1_000      # Default move delay in milliseconds
```

## Lobby UI

For open games where the current user is the game creator:
- Show a dropdown alongside the existing "Open" link
- Dropdown lists available strategies from `Games.list_strategies!()`
- Selecting a strategy sends `"bot_join_game"` event with `game_id` and `strategy` params
- Handler calls `Games.bot_join!(game, strategy, actor: user)`
- User is navigated to the game page

## Future: AI Strategy

A future `Bot.Strategies.Ai` could:
- Use AshAI to call an LLM for move selection
- Leverage the chat feature to "think out loud" (post messages explaining its reasoning)
- Would naturally have longer delays due to LLM latency
- Might need a Task.Supervisor (like the Commentator) for async LLM calls
- The behaviour interface remains the same; only `select_move/1` changes
