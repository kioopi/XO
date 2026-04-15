# Xo: Tic-Tac-Toe with Ash Framework

---

## What is Ash?

A **declarative, extensible framework** for building Elixir applications.

- Not a web framework — it sits *below* Phoenix
- You model your domain: resources, actions, relationships
- Ash handles the plumbing: persistence, authorization, validation, queries, PubSub, forms...

Built on **Spark** (the DSL engine that powers Ash's declarative syntax)
and **Igniter** (code generation and patching for Elixir projects).

---

## "Model your domain, derive the rest"

This is the thesis of this talk.

You describe **what** your app does.
Ash handles **how**.

By the end you'll have seen this pattern three times — and hopefully be convinced.

---

## The Ash Ecosystem

```
                    AshAuthentication
                          |
           AshPostgres -- Ash -- AshPhoenix
                          |
                AshAi -- Ash -- AshGraphql
                          |
                    AshJsonApi    AshAdmin
```

Extensions plug into the same domain model.
Define once, derive many interfaces.

---

## The Project

Let's build a **tic-tac-toe** game and see how far declarations take us.

Three features, growing in complexity:

1. **Core game** — the fundamentals of Ash
2. **AI commentator** — extending the domain with AshAi
3. **Bot player** — stretching Ash beyond the database

---
---

# Act 1: The Core Game

## Model your domain

---

## Accounts & AshAuthentication

Users come from AshAuthentication. Auth is declared, not built.

```elixir
# lib/xo/accounts/user.ex
use Ash.Resource,
  extensions: [AshAuthentication]

authentication do
  strategies do
    magic_link do
      identity_field :email
      registration_enabled? true
      sender Xo.Accounts.User.Senders.SendMagicLinkEmail
    end

    remember_me :remember_me
  end
end
```

No login controller. No session management code.

---

## The Game Resource

<!-- EDITOR: open lib/xo/games/game.ex and walk through -->

```elixir
use Ash.Resource,
  domain: Xo.Games,
  data_layer: AshPostgres.DataLayer,
  authorizers: [Ash.Policy.Authorizer],
  notifiers: [Ash.Notifier.PubSub]
```

Everything about the Game is declared in one place:
attributes, actions, relationships, calculations, aggregates, policies, PubSub.

---

## Actions — Where Behavior Lives

```elixir
actions do
  defaults [:read, :destroy]

  read :open, filter: expr(state == :open)
  read :active, filter: expr(state == :active)

  create :create do
    change relate_actor(:player_o, allow_nil?: false)
  end

  update :join do
    validate {ValidateGameState, states: [:open]}
    change relate_actor(:player_x, allow_nil?: false)
  end

  update :make_move do
    argument :field, :integer, allow_nil?: false,
      constraints: [min: 0, max: 8]

    validate {ValidateGameState, states: :active}
    change Changes.CreateMove
  end
end
```

Actions are not CRUD endpoints. They are **named operations** with arguments,
validations, and changes — all composable.

---

## Relationships

```elixir
relationships do
  belongs_to :player_o, User do
    allow_nil? false
  end

  belongs_to :player_x, User

  has_many :moves, Xo.Games.Move
  has_many :messages, Xo.Games.Message
end
```

Relationships are not just schema — they're **queryable**, **loadable**,
and usable in **expressions** and **aggregates**.

---

## The Move Resource & the Changeset Pipeline

<!-- EDITOR: open lib/xo/games/move.ex, then show changes -->

```elixir
# lib/xo/games/changes/create_move.ex
def change(changeset, _opts, _context) do
  field = Ash.Changeset.get_argument(changeset, :field)
  game_id = changeset.data.id

  Ash.Changeset.manage_relationship(
    changeset, :moves,
    [%{field: field, game_id: game_id}],
    type: :create
  )
end
```

Changes are **composable units of logic** that plug into the action pipeline.
`before_action`, `after_action`, `set_context` — the changeset carries data
through the pipeline.

---

## Validations

```elixir
# On Game:
validate {ValidateGameState, states: :active}

# On Move:
validate Validations.ValidatePlayerTurn
```

Validations are declared on the action, not scattered through controllers.
They're part of the domain — enforced no matter how the action is called.

---

## Calculations — Derived, Never Stored

```elixir
calculations do
  calculate :state, :atom, Calculations.GameState
  calculate :board, {:array, :atom}, Calculations.Board
  calculate :winner_id, :integer, Calculations.WinnerId
  calculate :available_fields, {:array, :integer}, Calculations.AvailableFields

  calculate :next_player_id, :integer,
    expr(if(rem(move_count, 2) == 0, player_o_id, player_x_id))
end
```

The game state is **never persisted** — it's always computed.
The board is a calculation over moves. The winner is a calculation over the board.

Calculations can be Elixir modules or inline expressions.
Expressions can run in the database for filtering and sorting.

---

## Calculations — How They Work

<!-- EDITOR: open lib/xo/games/calculations/game_state.ex -->

```elixir
defp game_state(%{player_x_id: x}) when is_nil(x), do: :open
defp game_state(%{winner_id: w}) when not is_nil(w), do: :won
defp game_state(%{move_count: 9}), do: :draw
defp game_state(_), do: :active
```

Pattern matching on loaded data. The calculation declares what it needs:

```elixir
def load(_query, _opts, _context) do
  [:player_x_id, :winner_id, :move_count]
end
```

Ash handles the loading. You write the logic.

---

## Aggregates — Push Computation to the Database

```elixir
aggregates do
  count :move_count, :moves

  list :player_o_fields, :moves, :field do
    filter expr(player_id == parent(player_o_id))
  end

  list :player_x_fields, :moves, :field do
    filter expr(player_id == parent(player_x_id))
  end
end
```

Aggregates are database-level computations over relationships.
Calculations use them — `:board` loads `:player_o_fields` and `:player_x_fields`.

No N+1 queries. No manual SQL. Declare what you need.

---

## Policies — Authorization as Declarations

```elixir
policies do
  policy action_type(:read) do
    authorize_if always()
  end

  policy action(:join) do
    forbid_unless expr(is_nil(player_x_id))
    forbid_unless expr(player_o_id != ^actor(:id))
    authorize_if always()
  end

  policy action(:make_move) do
    authorize_if expr(next_player_id == ^actor(:id))
  end
end
```

Authorization lives on the resource, not in controllers.
It's enforced everywhere — LiveView, API, console, tests.

---
---

# Act 1: The Core Game

## Derive the rest

---

## PubSub — For Free

```elixir
pub_sub do
  module XoWeb.Endpoint
  prefix "game"

  publish :create, "created"
  publish :create, "lobby"
  publish :join, [:_pkey],
    load: [:state, :board, :player_o, :player_x, :next_player_id]
  publish :make_move, [:_pkey],
    load: [:state, :board, :winner_id, :next_player_id, :available_fields]
end
```

I never call `Phoenix.PubSub.broadcast` in my domain code.
Declare which actions publish to which topics. Real-time updates just work.

---

## AshPhoenix Forms

```elixir
# The domain uses AshPhoenix
use Ash.Domain, extensions: [AshPhoenix]

# In GameLive — a form for chat messages:
defp new_message_form(game_id, user) do
  Games.form_to_create_message(
    actor: user,
    prepare_source: fn changeset ->
      Ash.Changeset.force_change_attribute(changeset, :game_id, game_id)
    end
  )
  |> to_form()
end
```

Ash knows your actions, their arguments, and their validations.
It generates form changesets that Phoenix understands.

`AshPhoenix.Form.validate()` and `.submit()` replace manual changeset wiring.

---

## The UI Payoff

<!-- EDITOR: open lib/xo_web/live/game_live.ex -->

The entire GameLive is **~150 lines**. It does three things:

1. Subscribe to PubSub
2. Call Ash actions
3. Render

```elixir
def handle_event("make_move", %{"field" => field_str}, socket) do
  Games.make_move!(socket.assigns.game, String.to_integer(field_str),
    actor: socket.assigns.current_user)
  {:noreply, socket}
end
```

No business logic in the web layer. The LiveView is a thin client
over the domain.

---

## The Domain — Clean and Declarative

```elixir
# lib/xo/games.ex
use Ash.Domain, extensions: [AshPhoenix],
  fragments: [Xo.Games.Commentator.DomainFragment,
              Xo.Games.Bot.DomainFragment]

resources do
  resource Xo.Games.Game do
    define :create_game, action: :create
    define :join, action: :join
    define :make_move, action: :make_move, args: [:field]
    define :get_by_id, action: :read, get_by: [:id]
  end

  resource Xo.Games.Move

  resource Xo.Games.Message do
    define :create_message, action: :create, args: [:body]
  end
end
```

`define` generates convenient functions like `Games.make_move!(game, field, actor: user)`.
The domain is the public API. Resources are the implementation.

---

## Messages — Adding a Resource is Trivial

<!-- EDITOR: open lib/xo/games/message.ex briefly -->

`Message` is a simple resource: `:body` attribute, belongs to `:user` and `:game`,
PubSub on create, policies for auth.

It immediately gets: forms, PubSub, authorization, validation.
Because that's what the domain model gives you.

---

## Act 1 Recap

We declared:
- **3 resources** (Game, Move, Message) with relationships, actions, calculations, aggregates
- **Authorization policies** on the resource
- **PubSub** topics per action

We got for free:
- Real-time updates across all clients
- Form changesets with validation
- A ~150-line LiveView with zero business logic
- Authorization enforced everywhere

**"Model your domain, derive the rest."**

---
---

# Act 2: Adding Intelligence

## The AI Commentator

---

## The Premise

We have a working game. Now:

**What if an AI watched the game and commented on it?**

The interesting question isn't "how do you call an LLM" —
it's **how do you extend an existing Ash domain without touching it?**

---

## Fragments — Extending Without Modifying

<!-- EDITOR: open lib/xo/games/commentator/game_fragment.ex -->

```elixir
# lib/xo/games/commentator/game_fragment.ex
defmodule Xo.Games.Commentator.GameFragment do
  use Spark.Dsl.Fragment, of: Ash.Resource,
    authorizers: [Ash.Policy.Authorizer]

  actions do
    action :generate_commentary, :string do
      argument :game_id, :integer, allow_nil?: false
      argument :event_description, :string, allow_nil?: false
      run Xo.Games.Commentator.GenerateCommentary
    end

    # ...
  end
end
```

I added new actions to the Game resource **without opening `game.ex`**.
Fragments let you extend resources from the outside.
This is how you keep concerns separated in Ash.

---

## AshAi — Your Domain Becomes the AI's Tools

```elixir
action :generate_commentary_with_tools, :string do
  run AshAi.Actions.prompt(
    fn _input, _context -> Xo.Games.LLM.build() end,
    tools: [:read_game, :read_moves],
    prompt: {@commentator_system_prompt,
      "Game ID: <%= @input.arguments.game_id %>
       Event: <%= @input.arguments.event_description %>

       Use the available tools to look up the current
       game state, then produce a brief commentary."}
  )
end
```

The domain you modeled in Act 1 is now **queryable by an LLM**.
Your Ash read actions become the AI's tools.
You didn't write any glue code — AshAi bridges the gap.

---

## The GenServer Bridge

<!-- EDITOR: open lib/xo/games/commentator/server.ex -->

```elixir
def init(game_id) do
  Phoenix.PubSub.subscribe(Xo.PubSub, "game:#{game_id}")
  {:ok, %{game_id: game_id, bot: nil}, {:continue, :greet}}
end

def handle_info(%Phoenix.Socket.Broadcast{event: event} = broadcast, state) do
  case classify_event(event, broadcast.payload) do
    {:comment, description} ->
      generate_and_post(state.game_id, state.bot, description)
      {:noreply, state}
    :game_over ->
      generate_and_post(state.game_id, state.bot, "The game has ended!")
      Process.send_after(self(), :shutdown, 5_000)
      {:noreply, state}
    # ...
  end
end
```

Ash handles the domain. OTP handles the process lifecycle.
They compose naturally — PubSub (declared in Act 1) feeds events to the GenServer.

---

## Supervision

```
Xo.Games.Commentator.Supervisor
  ├── Registry (CommentatorRegistry)
  ├── DynamicSupervisor (CommentatorSupervisor)
  │     └── [per-game Commentator.Server instances]
  └── Task.Supervisor (CommentatorTaskSupervisor)
```

Each game gets its own commentator process.
If it crashes, only that game's commentator restarts.
Standard OTP — Ash doesn't replace it, it works alongside it.

---

## How It's Started — An Ash Change

```elixir
# In Game's :join action
update :join do
  validate {ValidateGameState, states: [:open]}
  change relate_actor(:player_x, allow_nil?: false)
  change Xo.Games.Commentator.StartCommentator  # <-- this
end
```

The commentator starts as an `after_action` hook on `:join`.
When a second player joins, the commentator boots up.

The commentary posts through the same `Message` resource.
The chat UI didn't change.

---

## Act 2 Recap

We added AI commentary to the game.

- The existing **Game resource**, its actions, its PubSub — **all reused**
- **Fragments** added new actions without modifying `game.ex`
- **AshAi** turned our domain into an AI tool interface
- The commentator posts through the **same Message resource**
- The chat UI **didn't change at all**

This is what a strong domain model gives you — not just at the start,
but when you extend the project months later.

---
---

# Act 3: Stretching the Model

## The Bot Player

---

## The Premise

We want bot players with different strategies.

But strategies aren't database rows — they're **hardcoded Elixir modules**.

Can Ash model that?

---

## Ash.DataLayer.Simple

```elixir
# lib/xo/games/bot/strategy.ex
use Ash.Resource, data_layer: Ash.DataLayer.Simple

@modules %{
  random: Xo.Games.Bot.Strategies.Random,
  strategic: Xo.Games.Bot.Strategies.Strategic
}

attributes do
  attribute :key, :atom, primary_key?: true
  attribute :name, :string
  attribute :description, :string
end

actions do
  read :read do
    manual fn _, _, _ ->
      strategies = for module <- all_modules() do
        struct!(__MODULE__, module.info())
      end
      {:ok, strategies}
    end
  end
end
```

A resource backed by **code, not a database**. Ash doesn't care where data comes from.

---

## Elixir Behaviours Meeting Ash

```elixir
# lib/xo/games/bot/behaviour.ex
@callback info() :: %{key: atom(), name: String.t(), description: String.t()}
@callback bot_email() :: String.t()
@callback select_move(game :: Ash.Resource.record()) :: {:ok, non_neg_integer()}
```

<!-- EDITOR: show lib/xo/games/bot/strategies/strategic.ex -->

The strategies are **plain Elixir modules** with a behaviour contract.
Ash wraps them as a queryable resource. Both paradigms coexist.

Ash doesn't take over your application. It works alongside idiomatic Elixir.

---

## Fragments Again — Same Pattern, New Feature

```elixir
# lib/xo/games/bot/join_game.ex
def change(changeset, _opts, _context) do
  strategy_key = Ash.Changeset.get_argument(changeset, :strategy)
  strategy_module = Strategy.module_for!(strategy_key)
  bot_user = BotUser.user(strategy_module)

  changeset
  |> Ash.Changeset.force_change_attribute(:player_x_id, bot_user.id)
  |> Ash.Changeset.after_action(fn _changeset, game ->
    DynamicSupervisor.start_child(
      Xo.Games.BotSupervisor,
      {Xo.Games.Bot.Server, {game.id, strategy_module, bot_user}}
    )
    {:ok, game}
  end)
end
```

Same pattern as the commentator: an Ash change that bridges domain and OTP.

---

## Bot.Server — Same API as a Human

<!-- EDITOR: open lib/xo/games/bot/server.ex -->

```elixir
def handle_info(:execute_move, state) do
  game = Games.get_by_id!(state.game_id, authorize?: false)
  {:ok, field} = state.strategy.select_move(game)
  Games.make_move!(game, field, actor: state.bot_user)
  {:noreply, state}
end
```

The bot calls `Games.make_move!` — **the exact same function a human uses**.
The domain doesn't know or care who's calling it.

Same actions. Same PubSub. Same authorization model.

---

## Act 3 Recap

We added bot players.

- **Ash.DataLayer.Simple** — a resource backed by code, not a database
- **Elixir Behaviours** — plain modules that Ash wraps as a queryable resource
- **Fragments** — same pattern as the commentator, extending without modifying
- The bot uses the **same API as a human player**
- The lobby just needed a **dropdown**. The game UI didn't change.

---
---

# Closing

---

## What We Built

Three features on one domain model:

| Feature | What we wrote | What Ash derived |
|---------|--------------|-----------------|
| Core game | Resources, calculations, changes | PubSub, forms, authorization, queries |
| AI commentator | Fragment + GenServer | AI tool interface from existing actions |
| Bot player | Behaviour + in-memory resource | Queryable strategies, same domain API |

The domain model is not just convenient at the start.
It's **infrastructure** that pays dividends every time you extend the project.

---

## The Ecosystem

What we didn't cover — but the same domain can derive:

- **AshAdmin** — admin UI out of the box
- **AshGraphql** — GraphQL API from the same resources
- **AshJsonApi** — JSON:API from the same resources
- **AshStateMachine** — state machine behaviors on resources

Define once. Derive many interfaces.

---

## Try It

- **Ash HQ**: [ash-hq.org](https://ash-hq.org)
- **This project**: (your repo link)
- **Community**: Discord, Elixir Forum, hex.pm

Model a small domain. See what Ash derives for you.

---

*Thank you!*
