# Xo — Tic-Tac-Toe with Ash Framework

A tic-tac-toe game built to demonstrate the features and capabilities of the [Ash Framework](https://hexdocs.pm/ash) and its declarative approach to building Elixir applications.

Rather than writing imperative controllers, hand-rolled validations, and manual SQL queries, Xo defines its entire domain — resources, actions, authorization, real-time events — declaratively within the resource modules. Ash handles the rest.

## What This Demonstrates

### Declarative Resources

The domain is split into two Ash domains:

- **Accounts** — `Xo.Accounts.User` with magic-link authentication via [AshAuthentication](https://hexdocs.pm/ash_authentication)
- **Games** — `Xo.Games.Game` and `Xo.Games.Move`, the core game logic

The **Game** resource (`lib/xo/games/game.ex`) showcases several Ash features in a single module:

- **Attributes & Relationships** — A game belongs to `player_o` (creator) and optionally `player_x` (joiner), and has many `moves`
- **Actions** — `:create`, `:join`, `:make_move`, plus a filtered read `:open` that returns only games waiting for a second player
- **Calculations** — Derived fields like `state`, `winner_id`, `board`, `next_player_id`, and `available_fields` are defined declaratively, with both in-memory and SQL expression implementations
- **Aggregates** — `move_count`, `player_o_fields`, and `player_x_fields` aggregate data from the moves relationship
- **Policies** — Authorization rules enforce that only the correct player can move, you can't join your own game, and games must be in the right state for each action
- **PubSub** — Real-time event publishing via `Ash.Notifier.PubSub`

The **Move** resource (`lib/xo/games/move.ex`) demonstrates custom changes and validations:

- **Identity constraints** ensure no duplicate fields or move numbers per game
- **Custom changes** (`LoadGame`, `SetMoveNumber`) derive the move number from the game state
- **Custom validations** (`ValidatePlayerTurn`) enforce turn order

### Game State Without a State Machine

Game state (`:open`, `:active`, `:won`, `:draw`) is a **calculation** derived from the data, not a stored column:

- No `player_x`? The game is `:open`
- Both players, no winner, fewer than 9 moves? It's `:active`
- A winning combination detected? It's `:won`
- 9 moves with no winner? It's a `:draw`

This means state is always consistent — it's impossible for the stored state to drift from reality because there is no stored state.

### Code Interface

The `Xo.Games` domain (`lib/xo/games.ex`) exposes a clean API via Ash's `define` macro:

```elixir
Games.create_game!(actor: player)
Games.list_open_games!()
Games.join!(game, actor: other_player)
Games.make_move!(game, 4, actor: player)
Games.get_by_id!(42)
```

### PubSub Events

The Game resource publishes events via `Ash.Notifier.PubSub` for real-time UI updates. Two subscriber patterns are supported:

**Lobby** — for listing available games:
- `game:created` — a new open game appeared (loads state and player_o)
- `game:activity:<id>` — a game was joined or destroyed (remove from list)

**Game view** — for watching a specific game:
- `game:<id>` — player joined (loads state, board, both players), move made (loads state, board, winner, next player, available fields), or game destroyed

### Authorization Policies

Every action has declarative policy rules:

- **Create** — requires an actor (authenticated user)
- **Join** — actor must exist, game must be `:open`, actor must not be the creator, player_x slot must be empty
- **Make move** — actor must be the player whose turn it is (`next_player_id == actor.id`)

## Getting Started

```bash
mix setup        # Install deps, create DB, run migrations
iex -S mix       # Start an interactive session
```

## Interactive Demo

When you start `iex -S mix`, two demo users are automatically created and available as variables:

- `x` — Xavier (xavier@example.com)
- `o` — Olga (olga@example.com)

Use `Demo.help()` to see all available helpers:

```elixir
Demo.help()      # Overview of all demo helpers
Demo.users()     # Show demo users
Demo.games()     # Game creation & joining examples
Demo.moves()     # Making moves & gameplay examples
```

### Example Session

```elixir
# Create a game (x becomes player_o)
game = Games.create_game!(actor: x)

# List open games waiting for an opponent
Games.list_open_games!()

# Another player joins
game = Games.join!(game, actor: o)

# Play moves — fields are numbered 0-8:
#
#   0 | 1 | 2
#  ---+---+---
#   3 | 4 | 5
#  ---+---+---
#   6 | 7 | 8

game = Games.make_move!(game, 0, actor: x)
game = Games.make_move!(game, 4, actor: o)
game = Games.make_move!(game, 1, actor: x)
game = Games.make_move!(game, 3, actor: o)
game = Games.make_move!(game, 2, actor: x)
# x wins with the top row!

# Inspect the game state
Demo.show(game)

# View the board
Demo.board(game)
```

### AI Commentator

The game features an AI commentator powered by [AshAi](https://hexdocs.pm/ash_ai) that joins the chat panel and reacts to moves with witty commentary. It demonstrates:

- **Prompt-backed actions** — An Ash generic action where the implementation is an LLM call via `AshAi.Actions.prompt/2`
- **AshAi tools** — Exposing Ash read actions as tools the LLM can call to query game state
- **OTP integration** — A per-game `GenServer` subscribes to PubSub events and spawns async tasks for LLM calls

To enable the commentator, set an API key for your chosen LLM provider:

```bash
# Using Anthropic (default)
ANTHROPIC_API_KEY=sk-ant-... mix phx.server

# Using OpenAI
LLM_PROVIDER=openai OPENAI_API_KEY=sk-... mix phx.server
```

#### Commentary Modes

The commentator supports two modes, controlled by the `COMMENTATOR_USE_TOOLS` environment variable:

- **Direct context** (default): The commentator loads game state and passes it as text to the LLM. Works with any provider.
- **AshAi tools** (`COMMENTATOR_USE_TOOLS=true`): The LLM uses AshAi tool definitions (`read_game`, `read_moves`) to query game data itself, showcasing AshAi's tool integration.

```bash
# AshAi tools mode with OpenAI (recommended — showcases tool integration)
LLM_PROVIDER=openai OPENAI_API_KEY=sk-... COMMENTATOR_USE_TOOLS=true mix phx.server

# AshAi tools mode with Anthropic (blocked by upstream bug, see below)
ANTHROPIC_API_KEY=sk-ant-... COMMENTATOR_USE_TOOLS=true mix phx.server
```

> **Note:** The tools mode with Anthropic currently hits an upstream bug in `ash_ai` 0.5.0 where nested object schemas in tool definitions are missing `additionalProperties: false`, which the Anthropic API strictly requires. Use OpenAI for the tools mode, or use the default direct context mode with Anthropic. See `docs/ash_ai_additional_properties_bug.md` for details.

#### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `LLM_PROVIDER` | `anthropic` | LLM provider: `anthropic` or `openai` |
| `ANTHROPIC_API_KEY` | — | API key for Anthropic (required when provider is `anthropic`) |
| `OPENAI_API_KEY` | — | API key for OpenAI (required when provider is `openai`) |
| `COMMENTATOR_USE_TOOLS` | `false` | Set to `true` to use AshAi tools mode |

## Project Structure

```
lib/xo/
  accounts/
    user.ex              # User resource with AshAuthentication
    token.ex             # Authentication tokens
  games/
    game.ex              # Game resource (actions, policies, calculations, pubsub)
    move.ex              # Move resource (field, move_number, validations)
    message.ex           # Chat message resource with pubsub
    commentator.ex       # AI commentator GenServer (subscribes to game events)
    commentator_bot.ex   # Bot user management (creates/caches the bot user)
    calculations/        # GameState, WinnerId, Board, AvailableFields
    changes/             # CreateMove, StartCommentator
    validations/         # ValidateGameState
    move/changes/        # LoadGame, SetMoveNumber
    move/validations/    # ValidatePlayerTurn
  games.ex               # Games domain with AshAi tools and code interface
  accounts.ex            # Accounts domain
  demo.ex                # IEx REPL helpers
```

## Learn More

- [Ash Framework](https://hexdocs.pm/ash) — The declarative framework powering this project
- [AshAi](https://hexdocs.pm/ash_ai) — AI integration with prompt-backed actions and LLM tools
- [Ash PubSub](https://hexdocs.pm/ash/Ash.Notifier.PubSub.html) — Built-in notifier for real-time events
- [AshAuthentication](https://hexdocs.pm/ash_authentication) — Authentication strategies
- [AshPostgres](https://hexdocs.pm/ash_postgres) — PostgreSQL data layer
- [Phoenix Framework](https://hexdocs.pm/phoenix) — The web framework underneath
