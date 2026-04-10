# Commentator Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all AI Commentator modules into `lib/xo/games/commentator/` under the `Xo.Games.Commentator.*` namespace, then update all references.

**Architecture:** Pure file-move refactor. Six modules move into a shared directory. Ash fragments continue composing into the existing `Xo.Games` domain and `Xo.Games.Game` resource — only their module names change. No behavioral changes.

**Tech Stack:** Elixir, Ash Framework (Spark DSL fragments)

**Spec:** `docs/superpowers/specs/2026-04-08-commentator-reorganization-design.md`

---

### Task 1: Create new files under `lib/xo/games/commentator/`

Create all six new files with updated module names. Each file is a copy of the original with the module name changed and internal references updated.

**Files:**
- Create: `lib/xo/games/commentator/server.ex`
- Create: `lib/xo/games/commentator/bot.ex`
- Create: `lib/xo/games/commentator/domain_fragment.ex`
- Create: `lib/xo/games/commentator/game_fragment.ex`
- Create: `lib/xo/games/commentator/generate_commentary.ex`
- Create: `lib/xo/games/commentator/start_commentator.ex`

- [ ] **Step 1: Create `lib/xo/games/commentator/bot.ex`**

```elixir
defmodule Xo.Games.Commentator.Bot do
  @moduledoc "Manages the AI commentator bot user."

  @bot_email "commentator@xo.bot"
  @bot_name "Commentator"
  @persistent_term_key :commentator_bot_user

  require Ash.Query

  @doc "Returns the bot user, creating it if necessary."
  def user do
    case :persistent_term.get(@persistent_term_key, nil) do
      nil -> ensure_user()
      user -> user
    end
  end

  defp ensure_user do
    user =
      case Xo.Accounts.User
           |> Ash.Query.filter(email == ^@bot_email)
           |> Ash.read_one!(authorize?: false) do
        nil ->
          Xo.Accounts.demo_create_user!(@bot_name, @bot_email)

        existing ->
          existing
      end

    :persistent_term.put(@persistent_term_key, user)
    user
  end
end
```

- [ ] **Step 2: Create `lib/xo/games/commentator/server.ex`**

Note the two internal reference changes: `Xo.Games.CommentatorBot` → `Xo.Games.Commentator.Bot`.

```elixir
defmodule Xo.Games.Commentator.Server do
  @moduledoc "Per-game GenServer that subscribes to game events and posts AI commentary to chat."

  use GenServer
  require Logger

  alias Xo.Games

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via(game_id))
  end

  def via(game_id) do
    {:via, Registry, {Xo.Games.CommentatorRegistry, game_id}}
  end

  @impl true
  def init(game_id) do
    Phoenix.PubSub.subscribe(Xo.PubSub, "game:#{game_id}")
    {:ok, %{game_id: game_id, bot: nil}, {:continue, :greet}}
  end

  @impl true
  def handle_continue(:greet, state) do
    bot = Xo.Games.Commentator.Bot.user()

    try do
      generate_and_post(
        state.game_id,
        bot,
        "Both players have joined. The game is about to begin"
      )
    rescue
      e -> Logger.error("Commentator greeting failed: #{Exception.message(e)}")
    end

    {:noreply, %{state | bot: bot}}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event}, %{bot: nil} = state) do
    # Bot not yet initialized, ignore events
    Logger.debug("Commentator for game #{state.game_id} received event before init: #{event}")
    {:noreply, state}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: event} = broadcast, state) do
    case classify_event(event, broadcast.payload) do
      {:comment, description} ->
        generate_and_post(state.game_id, state.bot, description)
        {:noreply, state}

      :game_over ->
        generate_and_post(state.game_id, state.bot, "The game has ended! Summarize the result.")
        # Allow time for the async commentary task to complete before stopping
        Process.send_after(self(), :shutdown, 5_000)
        {:noreply, state}

      :abandoned ->
        {:stop, :normal, state}

      :ignore ->
        {:noreply, state}
    end
  end

  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  defp classify_event("make_move", %{data: game}) do
    case game.state do
      :won -> :game_over
      :draw -> :game_over
      :active -> {:comment, "A move was just made. The game is still active."}
      _ -> :ignore
    end
  end

  defp classify_event("destroy", _payload) do
    :abandoned
  end

  defp classify_event(_event, _payload), do: :ignore

  defp generate_and_post(game_id, bot, event_description) do
    Task.Supervisor.start_child(Xo.Games.CommentatorTaskSupervisor, fn ->
      try do
        commentary = Games.generate_commentary!(game_id, event_description, actor: bot)
        post_message(game_id, bot, commentary)
      rescue
        e ->
          Logger.error("Commentator failed: #{Exception.message(e)}")
      end
    end)
  end

  defp post_message(game_id, bot, body) do
    Games.create_message!(body, %{game_id: game_id}, actor: bot)
  end
end
```

- [ ] **Step 3: Create `lib/xo/games/commentator/generate_commentary.ex`**

```elixir
defmodule Xo.Games.Commentator.GenerateCommentary do
  @moduledoc """
  Dispatches commentary generation to either the tools-based or context-based action
  depending on the `:commentator_use_tools` application config.
  """

  use Ash.Resource.Actions.Implementation

  alias Xo.Games.GameSummary

  @impl true
  def run(input, _opts, context) do
    input.resource
    |> generate_commentary_action_input(
      Application.get_env(:xo, :commentator_use_tools, false),
      %{
        game_id: input.arguments.game_id,
        event_description: input.arguments.event_description
      },
      actor: context.actor
    )
    |> Ash.run_action()
  end

  defp generate_commentary_action_input(resource, true, params, opts) do
    resource
    |> Ash.ActionInput.for_action(
      :generate_commentary_with_tools,
      params,
      opts
    )
  end

  defp generate_commentary_action_input(
         resource,
         # use tools
         false,
         %{game_id: id, event_description: description},
         opts
       ) do
    resource
    |> Ash.ActionInput.for_action(
      :generate_commentary_with_context,
      %{
        game_context: GameSummary.for_prompt(load_game!(id)),
        event_description: description
      },
      opts
    )
  end

  defp load_game!(game_id) do
    Xo.Games.get_by_id!(game_id,
      load: [
        :state,
        :board,
        :player_o,
        :player_x,
        :winner_id,
        :next_player_id,
        :move_count,
        moves: [:player]
      ],
      authorize?: false
    )
  end
end
```

- [ ] **Step 4: Create `lib/xo/games/commentator/start_commentator.ex`**

Note the reference change: `{Xo.Games.Commentator, game.id}` → `{Xo.Games.Commentator.Server, game.id}`.

```elixir
defmodule Xo.Games.Commentator.StartCommentator do
  @moduledoc "Starts the AI commentator GenServer when a player joins a game."

  use Ash.Resource.Change
  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, game ->
      if Application.get_env(:xo, :commentator_enabled, true) do
        case DynamicSupervisor.start_child(
               Xo.Games.CommentatorSupervisor,
               {Xo.Games.Commentator.Server, game.id}
             ) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to start commentator for game #{game.id}: #{inspect(reason)}")
        end
      end

      {:ok, game}
    end)
  end
end
```

- [ ] **Step 5: Create `lib/xo/games/commentator/domain_fragment.ex`**

```elixir
defmodule Xo.Games.Commentator.DomainFragment do
  use Spark.Dsl.Fragment,
    of: Ash.Domain,
    extensions: [AshAi]

  tools do
    tool :read_game, Xo.Games.Game, :read do
      description "Read game details including board state, players, and current status."
      load [:state, :board, :player_o, :player_x, :winner_id, :next_player_id, :move_count]
    end

    tool :read_moves, Xo.Games.Move, :read do
      description "Read the moves made in a game, including which player made each move and the board position."
      load [:player]
    end
  end

  resources do
    resource Xo.Games.Game do
      define :generate_commentary,
        action: :generate_commentary,
        args: [:game_id, :event_description]
    end
  end
end
```

- [ ] **Step 6: Create `lib/xo/games/commentator/game_fragment.ex`**

Note the reference change: `run Xo.Games.Actions.GenerateCommentary` → `run Xo.Games.Commentator.GenerateCommentary`.

```elixir
defmodule Xo.Games.Commentator.GameFragment do
  use Spark.Dsl.Fragment,
    of: Ash.Resource,
    authorizers: [Ash.Policy.Authorizer]

  require AshAi.Actions

  actions do
    @commentator_system_prompt """
    You are a witty and entertaining tic-tac-toe commentator in a game chat room.
    Keep your commentary to 1-2 short sentences. Be fun and engaging but not annoying.
    Reference players by name when possible. Do NOT use markdown formatting. Write plain text only
    """

    action :generate_commentary, :string do
      description """
      Generate commentary about a game event. Dispatches to either the tools-based or
      context-based action depending on the :commentator_use_tools application config.
      """

      argument :game_id, :integer do
        allow_nil? false
        description "The ID of the game to comment on."
      end

      argument :event_description, :string do
        allow_nil? false
        description "What just happened in the game."
      end

      run Xo.Games.Commentator.GenerateCommentary
    end

    action :generate_commentary_with_context, :string do
      description """
      Generate commentary about a game event. Game context is provided directly as text.
      """

      argument :game_context, :string do
        allow_nil? false
        description "A summary of the current game state including board, players, and moves."
      end

      argument :event_description, :string do
        allow_nil? false
        description "What just happened in the game."
      end

      run AshAi.Actions.prompt(
            fn _input, _context -> Xo.Games.LLM.build() end,
            adapter: AshAi.Actions.Prompt.Adapter.RequestJson,
            tools: false,
            prompt:
              {@commentator_system_prompt,
               "<%= @input.arguments.game_context %>\n\nEvent: <%= @input.arguments.event_description %>"}
          )
    end

    action :generate_commentary_with_tools, :string do
      description """
      Generate commentary about a game event using AshAi tools to query game state.
      The LLM can use read_game and read_moves tools to look up the current board, players, and move history.
      """

      argument :game_id, :integer do
        allow_nil? false
        description "The ID of the game to comment on."
      end

      argument :event_description, :string do
        allow_nil? false
        description "What just happened in the game."
      end

      run AshAi.Actions.prompt(
            fn _input, _context -> Xo.Games.LLM.build() end,
            adapter: AshAi.Actions.Prompt.Adapter.RequestJson,
            tools: [:read_game, :read_moves],
            prompt:
              {@commentator_system_prompt,
               "Game ID: <%= @input.arguments.game_id %>\nEvent: <%= @input.arguments.event_description %>\n\nUse the available tools to look up the current game state, then produce a brief commentary."}
          )
    end
  end

  policies do
    policy action([
             :generate_commentary,
             :generate_commentary_with_context,
             :generate_commentary_with_tools
           ]) do
      description "Authenticated users (including the bot) can generate commentary."
      authorize_if actor_present()
    end
  end
end
```

- [ ] **Step 7: Commit new files**

```bash
jj new -m "Add commentator modules under Xo.Games.Commentator namespace"
```

---

### Task 2: Update references in consuming modules

Update `game.ex`, `games.ex`, and `application.ex` to point to the new module names.

**Files:**
- Modify: `lib/xo/games/game.ex:8,41`
- Modify: `lib/xo/games.ex:7`

- [ ] **Step 1: Update fragment reference in `lib/xo/games/game.ex`**

Change line 8 from:
```elixir
    fragments: [__MODULE__.Commentator]
```
to:
```elixir
    fragments: [Xo.Games.Commentator.GameFragment]
```

Change line 41 from:
```elixir
      change Changes.StartCommentator
```
to:
```elixir
      change Xo.Games.Commentator.StartCommentator
```

- [ ] **Step 2: Update fragment reference in `lib/xo/games.ex`**

Change line 7 from:
```elixir
    fragments: [__MODULE__.CommentatorDomain]
```
to:
```elixir
    fragments: [Xo.Games.Commentator.DomainFragment]
```

- [ ] **Step 3: Compile to verify references**

Run: `mix compile --warnings-as-errors`
Expected: Successful compilation (warnings about old modules being redefined are OK at this point since we haven't deleted old files yet)

- [ ] **Step 4: Commit**

```bash
jj new -m "Update references to new Xo.Games.Commentator namespace"
```

---

### Task 3: Delete old files and verify

Remove the original files and clean up empty directories.

**Files:**
- Delete: `lib/xo/games/commentator.ex`
- Delete: `lib/xo/games/commentator_bot.ex`
- Delete: `lib/xo/games/commentator_domain.ex`
- Delete: `lib/xo/games/game/commentator.ex` (leaves `game/` dir empty — delete dir too)
- Delete: `lib/xo/games/actions/generate_commentary.ex` (leaves `actions/` dir empty — delete dir too)
- Delete: `lib/xo/games/changes/start_commentator.ex` (`changes/` dir still has `create_move.ex`)

- [ ] **Step 1: Delete old files**

```bash
rm lib/xo/games/commentator.ex
rm lib/xo/games/commentator_bot.ex
rm lib/xo/games/commentator_domain.ex
rm lib/xo/games/game/commentator.ex
rm lib/xo/games/actions/generate_commentary.ex
rm lib/xo/games/changes/start_commentator.ex
```

- [ ] **Step 2: Remove empty directories**

```bash
rmdir lib/xo/games/game
rmdir lib/xo/games/actions
```

- [ ] **Step 3: Compile clean**

Run: `mix compile --warnings-as-errors`
Expected: Clean compilation with no warnings or errors.

- [ ] **Step 4: Run tests**

Run: `mix test`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
jj new -m "Remove old commentator files and empty directories"
```

---

### Verification

After all tasks are complete:

1. `mix compile --warnings-as-errors` — no dangling references
2. `mix test` — no behavioral regressions
3. Confirm directory structure:
   ```bash
   ls lib/xo/games/commentator/
   ```
   Expected: `bot.ex  domain_fragment.ex  game_fragment.ex  generate_commentary.ex  server.ex  start_commentator.ex`
4. Confirm old files are gone:
   ```bash
   ls lib/xo/games/commentator.ex lib/xo/games/commentator_bot.ex lib/xo/games/commentator_domain.ex lib/xo/games/game/commentator.ex lib/xo/games/actions/generate_commentary.ex lib/xo/games/changes/start_commentator.ex 2>&1
   ```
   Expected: All "No such file or directory"
