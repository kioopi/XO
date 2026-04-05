# LiveView UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a two-page LiveView UI (lobby + game) for the XO tic-tac-toe app, with real-time PubSub updates, function components, and a presenter layer.

**Architecture:** Two LiveViews (`LobbyLive`, `GameLive`) own page state and PubSub subscriptions. A `GamePresenter` module shapes domain data for display. Four component modules provide reusable, stateless rendering. Ash domain actions are the sole source of truth for game logic.

**Tech Stack:** Elixir, Phoenix LiveView, Ash Framework, DaisyUI + Tailwind CSS, PostgreSQL

**Spec:** `docs/superpowers/specs/2026-04-05-liveview-ui-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `lib/xo/games/game.ex` | Modify | Add `:active` read action, add `game:lobby` PubSub publish lines |
| `lib/xo/games.ex` | Modify | Add `define :list_active_games` |
| `lib/xo_web/router.ex` | Modify | Add LiveView routes, remove PageController home route |
| `lib/xo_web/game_presenter.ex` | Create | UI-facing helper: role, status text, clickable fields |
| `lib/xo_web/components/game_ui.ex` | Create | Layout primitives: page_header, section, empty_state |
| `lib/xo_web/components/lobby_components.ex` | Create | Lobby components: games_list, game_card, game_state_badge |
| `lib/xo_web/components/game_components.ex` | Create | Game components: board, board_cell, game_header, game_status_banner, players_panel, player_card, action_bar |
| `lib/xo_web/live/lobby_live.ex` | Create | Lobby page LiveView |
| `lib/xo_web/live/game_live.ex` | Create | Game page LiveView |
| `test/xo_web/game_presenter_test.exs` | Create | Presenter unit tests |
| `test/xo/games/pub_sub_test.exs` | Modify | Add lobby topic tests |
| `test/xo/games/game_test.exs` | Modify | Add active read action tests |
| `test/xo_web/live/lobby_live_test.exs` | Create | Lobby LiveView tests |
| `test/xo_web/live/game_live_test.exs` | Create | Game LiveView tests |

---

## Task 1: Ash Domain Changes

Add the `:active` read action on Game and the `game:lobby` PubSub topic.

**Files:**
- Modify: `lib/xo/games/game.ex`
- Modify: `lib/xo/games.ex`
- Modify: `test/xo/games/game_test.exs`
- Modify: `test/xo/games/pub_sub_test.exs`

### Step 1: Write failing test for active read action

- [ ] Add to `test/xo/games/game_test.exs`, after the existing `describe "open read action"` block:

```elixir
describe "active read action" do
  test "returns only games with both players (active state)" do
    player_o = generate(user())
    player_x = generate(user())

    # Create an open game (should NOT appear)
    _open_game = generate(game(actor: generate(user())))

    # Create an active game (should appear)
    active_game = generate(game(actor: player_o))
    Ash.update!(active_game, %{}, action: :join, actor: player_x, authorize?: true)

    games = Ash.read!(Xo.Games.Game, action: :active)

    assert length(games) == 1
    assert hd(games).id == active_game.id
  end

  test "returns empty list when no active games" do
    _open_game = generate(game())

    assert Ash.read!(Xo.Games.Game, action: :active) == []
  end
end
```

- [ ] Run test to verify it fails:

```bash
mix test test/xo/games/game_test.exs --max-failures 1
```

Expected: compilation error or action not found.

### Step 2: Implement the active read action

- [ ] In `lib/xo/games/game.ex`, inside the `actions` block, after `read :open, filter: expr(state == :open)`, add:

```elixir
read :active, filter: expr(state == :active)
```

- [ ] In `lib/xo/games.ex`, inside the `resource Xo.Games.Game do` block, after the existing `define` lines, add:

```elixir
define :list_active_games, action: :active
```

- [ ] Run the test:

```bash
mix test test/xo/games/game_test.exs --max-failures 1
```

Expected: PASS

### Step 3: Write failing test for lobby PubSub topic

- [ ] Add to `test/xo/games/pub_sub_test.exs`, a new describe block at the end:

```elixir
describe "lobby topic" do
  test "create publishes to game:lobby" do
    subscribe("game:lobby")

    player = generate(user())
    Games.create_game!(actor: player)

    assert_notification(:create)
  end

  test "join publishes to game:lobby" do
    player_o = generate(user())
    game = Games.create_game!(actor: player_o)

    subscribe("game:lobby")

    player_x = generate(user())
    Games.join!(game, actor: player_x)

    assert_notification(:join)
  end

  test "destroy publishes to game:lobby" do
    player = generate(user())
    game = Games.create_game!(actor: player)

    subscribe("game:lobby")

    Ash.destroy!(game, authorize?: false)

    assert_notification(:destroy)
  end
end
```

- [ ] Run test to verify it fails:

```bash
mix test test/xo/games/pub_sub_test.exs --max-failures 1
```

Expected: FAIL — no message received.

### Step 4: Add lobby PubSub publish lines

- [ ] In `lib/xo/games/game.ex`, inside the `pub_sub` block, add these lines after the existing publish lines:

```elixir
publish :create, "lobby"
publish :join, "lobby"
publish :destroy, "lobby"
```

- [ ] Run the PubSub tests:

```bash
mix test test/xo/games/pub_sub_test.exs
```

Expected: all PASS

### Step 5: Run full test suite and commit

- [ ] Run full tests:

```bash
mix test
```

Expected: all PASS

- [ ] Commit:

```bash
jj describe -m "Add active read action and lobby PubSub topic"
jj new
```

---

## Task 2: GamePresenter

Build the presentation helper module with unit tests.

**Files:**
- Create: `lib/xo_web/game_presenter.ex`
- Create: `test/xo_web/game_presenter_test.exs`

### Step 1: Write failing tests for role/2

- [ ] Create `test/xo_web/game_presenter_test.exs`:

```elixir
defmodule XOWeb.GamePresenterTest do
  use ExUnit.Case, async: true

  alias XOWeb.GamePresenter

  # Minimal structs for testing — no database needed
  defp game(attrs \\ %{}) do
    Map.merge(
      %{
        player_o_id: 1,
        player_x_id: 2,
        state: :active,
        next_player_id: 1,
        available_fields: [0, 1, 2, 3, 4, 5, 6, 7, 8],
        winner_id: nil,
        player_o: %{id: 1, name: "Olga"},
        player_x: %{id: 2, name: "Xavier"}
      },
      attrs
    )
  end

  defp user(id), do: %{id: id}

  describe "role/2" do
    test "returns :spectator for nil user" do
      assert GamePresenter.role(game(), nil) == :spectator
    end

    test "returns :player_o when user is player_o" do
      assert GamePresenter.role(game(), user(1)) == :player_o
    end

    test "returns :player_x when user is player_x" do
      assert GamePresenter.role(game(), user(2)) == :player_x
    end

    test "returns :spectator for unrelated user" do
      assert GamePresenter.role(game(), user(99)) == :spectator
    end
  end

  describe "your_mark/2" do
    test "returns :o for player_o" do
      assert GamePresenter.your_mark(game(), user(1)) == :o
    end

    test "returns :x for player_x" do
      assert GamePresenter.your_mark(game(), user(2)) == :x
    end

    test "returns nil for spectator" do
      assert GamePresenter.your_mark(game(), nil) == nil
    end
  end

  describe "clickable_fields/2" do
    test "returns available_fields when it is the user's turn" do
      g = game(%{next_player_id: 1, available_fields: [0, 3, 7]})
      assert GamePresenter.clickable_fields(g, user(1)) == [0, 3, 7]
    end

    test "returns empty list when it is not the user's turn" do
      g = game(%{next_player_id: 1})
      assert GamePresenter.clickable_fields(g, user(2)) == []
    end

    test "returns empty list for spectator" do
      assert GamePresenter.clickable_fields(game(), nil) == []
    end

    test "returns empty list when game is not active" do
      g = game(%{state: :won, next_player_id: 1})
      assert GamePresenter.clickable_fields(g, user(1)) == []
    end

    test "returns empty list when game is open" do
      g = game(%{state: :open, next_player_id: 1})
      assert GamePresenter.clickable_fields(g, user(1)) == []
    end
  end

  describe "status_text/2" do
    test "open game" do
      g = game(%{state: :open})
      assert GamePresenter.status_text(g, user(1)) == "Waiting for an opponent to join"
    end

    test "draw" do
      g = game(%{state: :draw})
      assert GamePresenter.status_text(g, user(1)) == "It's a draw!"
    end

    test "active game, your turn" do
      g = game(%{state: :active, next_player_id: 1})
      assert GamePresenter.status_text(g, user(1)) == "Your turn"
    end

    test "active game, opponent's turn (you are player_o)" do
      g = game(%{state: :active, next_player_id: 2})
      assert GamePresenter.status_text(g, user(1)) == "Xavier is thinking..."
    end

    test "active game, spectator" do
      g = game(%{state: :active, next_player_id: 1})
      assert GamePresenter.status_text(g, nil) == "Olga's turn"
    end

    test "won game, you won" do
      g = game(%{state: :won, winner_id: 1})
      assert GamePresenter.status_text(g, user(1)) == "You won!"
    end

    test "won game, you lost" do
      g = game(%{state: :won, winner_id: 1})
      assert GamePresenter.status_text(g, user(2)) == "Olga won"
    end

    test "won game, spectator sees winner" do
      g = game(%{state: :won, winner_id: 1})
      assert GamePresenter.status_text(g, nil) == "Olga won!"
    end
  end

  describe "winner_name/1" do
    test "returns winner name when player_o won" do
      g = game(%{winner_id: 1})
      assert GamePresenter.winner_name(g) == "Olga"
    end

    test "returns winner name when player_x won" do
      g = game(%{winner_id: 2})
      assert GamePresenter.winner_name(g) == "Xavier"
    end

    test "returns nil when no winner" do
      g = game(%{winner_id: nil})
      assert GamePresenter.winner_name(g) == nil
    end
  end

  describe "player_display/2" do
    test "returns display map for player_o" do
      g = game(%{state: :active, next_player_id: 1, winner_id: nil})
      result = GamePresenter.player_display(g, :player_o, user(1))

      assert result == %{
               name: "Olga",
               mark: :o,
               is_turn: true,
               is_winner: false,
               is_you: true
             }
    end

    test "returns display map for player_x as spectator" do
      g = game(%{state: :active, next_player_id: 2, winner_id: nil})
      result = GamePresenter.player_display(g, :player_x, nil)

      assert result == %{
               name: "Xavier",
               mark: :x,
               is_turn: true,
               is_winner: false,
               is_you: false
             }
    end

    test "marks winner correctly" do
      g = game(%{state: :won, next_player_id: 1, winner_id: 2})
      result = GamePresenter.player_display(g, :player_x, user(2))

      assert result == %{
               name: "Xavier",
               mark: :x,
               is_turn: false,
               is_winner: true,
               is_you: true
             }
    end
  end
end
```

- [ ] Run to verify it fails:

```bash
mix test test/xo_web/game_presenter_test.exs --max-failures 1
```

Expected: compilation error — module not found.

### Step 2: Implement GamePresenter

- [ ] Create `lib/xo_web/game_presenter.ex`:

```elixir
defmodule XOWeb.GamePresenter do
  @moduledoc """
  Shapes domain Game data for UI display.

  Pure functions — no Phoenix dependencies, no database access.
  Receives already-loaded game structs and derives presentation values.
  """

  def role(_game, nil), do: :spectator

  def role(game, user) do
    cond do
      user.id == game.player_o_id -> :player_o
      user.id == game.player_x_id -> :player_x
      true -> :spectator
    end
  end

  def your_mark(game, user) do
    case role(game, user) do
      :player_o -> :o
      :player_x -> :x
      :spectator -> nil
    end
  end

  def clickable_fields(game, user) do
    if game.state == :active and user_id(user) == game.next_player_id do
      game.available_fields || []
    else
      []
    end
  end

  def status_text(game, user) do
    role = role(game, user)

    case game.state do
      :open -> "Waiting for an opponent to join"
      :draw -> "It's a draw!"
      :won -> won_text(game, user, role)
      :active -> turn_text(game, user, role)
    end
  end

  def winner_name(game) do
    cond do
      game.winner_id == nil -> nil
      game.winner_id == game.player_o.id -> game.player_o.name
      game.winner_id == game.player_x.id -> game.player_x.name
      true -> nil
    end
  end

  def player_display(game, which_player, current_user) do
    {player, mark, player_id} =
      case which_player do
        :player_o -> {game.player_o, :o, game.player_o_id}
        :player_x -> {game.player_x, :x, game.player_x_id}
      end

    %{
      name: player.name,
      mark: mark,
      is_turn: game.state == :active and game.next_player_id == player_id,
      is_winner: game.winner_id != nil and game.winner_id == player_id,
      is_you: current_user != nil and current_user.id == player_id
    }
  end

  # Private helpers

  defp user_id(nil), do: nil
  defp user_id(user), do: user.id

  defp won_text(game, user, role) do
    name = winner_name(game)

    cond do
      role != :spectator and game.winner_id == user.id -> "You won!"
      role == :spectator -> "#{name} won!"
      true -> "#{name} won"
    end
  end

  defp turn_text(game, _user, :spectator) do
    name = next_player_name(game)
    "#{name}'s turn"
  end

  defp turn_text(game, user, _role) do
    if game.next_player_id == user.id do
      "Your turn"
    else
      name = next_player_name(game)
      "#{name} is thinking..."
    end
  end

  defp next_player_name(game) do
    if game.next_player_id == game.player_o_id do
      game.player_o.name
    else
      game.player_x.name
    end
  end
end
```

- [ ] Run the tests:

```bash
mix test test/xo_web/game_presenter_test.exs
```

Expected: all PASS

### Step 3: Commit

- [ ] Commit:

```bash
jj describe -m "Add GamePresenter module with unit tests"
jj new
```

---

## Task 3: GameUI Layout Components

Create the shared layout primitives.

**Files:**
- Create: `lib/xo_web/components/game_ui.ex`

### Step 1: Create the GameUI module

- [ ] Create `lib/xo_web/components/game_ui.ex`:

```elixir
defmodule XOWeb.GameUI do
  @moduledoc """
  Shared layout primitives for game pages.
  """
  use Phoenix.Component

  attr :title, :string, required: true
  slot :actions
  slot :inner_block

  def page_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-bold">{@title}</h1>
      <div :if={@actions != []} class="flex items-center gap-2">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <div class="mb-8">
      <h2 class="text-lg font-semibold mb-3">{@title}</h2>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :message, :string, required: true
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-8 text-base-content/60">
      <p>{@message}</p>
      <div :if={@actions != []} class="mt-4">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end
end
```

- [ ] Verify it compiles:

```bash
mix compile --warnings-as-errors
```

Expected: compiles without warnings.

### Step 2: Commit

- [ ] Commit:

```bash
jj describe -m "Add GameUI layout components"
jj new
```

---

## Task 4: LobbyComponents

Create the lobby-specific function components.

**Files:**
- Create: `lib/xo_web/components/lobby_components.ex`

### Step 1: Create the LobbyComponents module

- [ ] Create `lib/xo_web/components/lobby_components.ex`:

```elixir
defmodule XOWeb.LobbyComponents do
  @moduledoc """
  Function components for the lobby page.
  """
  use Phoenix.Component
  use XoWeb, :verified_routes

  attr :state, :atom, required: true

  def game_state_badge(assigns) do
    ~H"""
    <span class={["badge badge-sm", badge_class(@state)]}>
      {@state}
    </span>
    """
  end

  defp badge_class(:open), do: "badge-info"
  defp badge_class(:active), do: "badge-warning"
  defp badge_class(:won), do: "badge-success"
  defp badge_class(:draw), do: "badge-neutral"
  defp badge_class(_), do: "badge-ghost"

  attr :games, :list, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true

  def games_list(assigns) do
    ~H"""
    <div class="grid gap-3">
      <.game_card :for={game <- @games} game={game} current_user={@current_user} variant={@variant} />
    </div>
    """
  end

  attr :game, :any, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true

  def game_card(assigns) do
    ~H"""
    <div class="card card-border bg-base-100 shadow-sm">
      <div class="card-body p-4 flex-row items-center justify-between">
        <div class="flex items-center gap-3">
          <.game_state_badge state={@game.state} />
          <div>
            <span class="font-medium">{creator_name(@game)}</span>
            <span :if={@variant == :active && @game.player_x} class="text-base-content/60">
              vs {@game.player_x.name}
            </span>
            <span :if={@game.move_count > 0} class="text-sm text-base-content/50 ml-2">
              · {@game.move_count} moves
            </span>
          </div>
        </div>
        <div>
          <.card_action game={@game} current_user={@current_user} variant={@variant} />
        </div>
      </div>
    </div>
    """
  end

  defp creator_name(game), do: game.player_o.name

  attr :game, :any, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true

  defp card_action(%{variant: :open, current_user: nil} = assigns) do
    ~H"""
    <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost">
      Watch
    </.link>
    """
  end

  defp card_action(%{variant: :open, current_user: user, game: game} = assigns) do
    if user.id == game.player_o_id do
      ~H"""
      <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost">
        Open
      </.link>
      """
    else
      ~H"""
      <button phx-click="join_game" phx-value-game-id={@game.id} class="btn btn-sm btn-primary">
        Join
      </button>
      """
    end
  end

  defp card_action(%{variant: :active} = assigns) do
    ~H"""
    <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost">
      Watch
    </.link>
    """
  end
end
```

- [ ] Verify it compiles:

```bash
mix compile --warnings-as-errors
```

Expected: compiles without warnings.

### Step 2: Commit

- [ ] Commit:

```bash
jj describe -m "Add LobbyComponents"
jj new
```

---

## Task 5: GameComponents

Create the game view function components.

**Files:**
- Create: `lib/xo_web/components/game_components.ex`

### Step 1: Create the GameComponents module

- [ ] Create `lib/xo_web/components/game_components.ex`:

```elixir
defmodule XOWeb.GameComponents do
  @moduledoc """
  Function components for the game page.
  """
  use Phoenix.Component
  use XoWeb, :verified_routes

  attr :game, :any, required: true
  attr :role, :atom, required: true

  def game_header(assigns) do
    ~H"""
    <div class="flex items-center gap-3 mb-2">
      <h2 class="text-xl font-bold">Game #{@game.id}</h2>
      <.game_state_badge state={@game.state} />
      <span class="text-sm text-base-content/60">
        {role_label(@role)}
      </span>
    </div>
    """
  end

  defp role_label(:player_o), do: "You are O"
  defp role_label(:player_x), do: "You are X"
  defp role_label(:spectator), do: "Spectating"

  attr :state, :atom, required: true

  defp game_state_badge(assigns) do
    ~H"""
    <span class={["badge badge-sm", badge_class(@state)]}>
      {@state}
    </span>
    """
  end

  defp badge_class(:open), do: "badge-info"
  defp badge_class(:active), do: "badge-warning"
  defp badge_class(:won), do: "badge-success"
  defp badge_class(:draw), do: "badge-neutral"
  defp badge_class(_), do: "badge-ghost"

  attr :status_text, :string, required: true

  def game_status_banner(assigns) do
    ~H"""
    <div class="alert mb-4">
      <span class="text-lg font-medium">{@status_text}</span>
    </div>
    """
  end

  attr :board, :list, required: true
  attr :clickable_fields, :list, required: true
  attr :disabled, :boolean, default: false

  def board(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-1 w-full max-w-xs mx-auto aspect-square">
      <.board_cell
        :for={{value, index} <- Enum.with_index(@board)}
        value={value}
        index={index}
        clickable={not @disabled and index in @clickable_fields}
      />
    </div>
    """
  end

  attr :value, :atom, required: true
  attr :index, :integer, required: true
  attr :clickable, :boolean, required: true

  def board_cell(assigns) do
    ~H"""
    <button
      class={[
        "flex items-center justify-center aspect-square rounded-lg text-3xl font-bold",
        "min-h-16 min-w-16",
        cell_style(@value, @clickable)
      ]}
      disabled={not @clickable}
      phx-click={@clickable && "make_move"}
      phx-value-field={@clickable && @index}
    >
      <span :if={@value == :o} class="text-primary">O</span>
      <span :if={@value == :x} class="text-secondary">X</span>
      <span :if={is_nil(@value) and @clickable} class="text-base-content/20">·</span>
    </button>
    """
  end

  defp cell_style(nil, true), do: "bg-base-200 hover:bg-base-300 cursor-pointer"
  defp cell_style(nil, false), do: "bg-base-200"
  defp cell_style(_mark, _), do: "bg-base-200"

  attr :game, :any, required: true
  attr :role, :atom, required: true
  attr :current_user, :any, default: nil

  def players_panel(assigns) do
    assigns =
      assigns
      |> assign(:player_o_display, XOWeb.GamePresenter.player_display(assigns.game, :player_o, assigns.current_user))
      |> assign(:player_x_display, if(assigns.game.player_x, do: XOWeb.GamePresenter.player_display(assigns.game, :player_x, assigns.current_user)))

    ~H"""
    <div class="flex flex-col gap-3">
      <.player_card {@player_o_display} />
      <%= if @player_x_display do %>
        <.player_card {@player_x_display} />
      <% else %>
        <div class="card card-border bg-base-100 p-4 text-center text-base-content/50">
          Waiting for opponent...
        </div>
      <% end %>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :mark, :atom, required: true
  attr :is_turn, :boolean, required: true
  attr :is_winner, :boolean, required: true
  attr :is_you, :boolean, required: true

  def player_card(assigns) do
    ~H"""
    <div class={[
      "card card-border bg-base-100 p-4 flex-row items-center gap-3",
      @is_turn && "ring-2 ring-primary",
      @is_winner && "ring-2 ring-success"
    ]}>
      <span class={["text-xl font-bold", mark_color(@mark)]}>
        {mark_label(@mark)}
      </span>
      <span class="font-medium">{@name}</span>
      <span :if={@is_you} class="badge badge-sm badge-ghost">You</span>
      <span :if={@is_turn} class="badge badge-sm badge-primary">Turn</span>
      <span :if={@is_winner} class="badge badge-sm badge-success">Winner</span>
    </div>
    """
  end

  defp mark_label(:o), do: "O"
  defp mark_label(:x), do: "X"

  defp mark_color(:o), do: "text-primary"
  defp mark_color(:x), do: "text-secondary"

  attr :game, :any, required: true
  attr :role, :atom, required: true
  attr :current_user, :any, default: nil

  def action_bar(assigns) do
    ~H"""
    <div class="flex gap-2 mt-4">
      <button
        :if={show_join_button?(@game, @current_user)}
        phx-click="join_game"
        class="btn btn-primary"
      >
        Join Game
      </button>
      <.link navigate={~p"/"} class="btn btn-ghost">
        ← Back to Lobby
      </.link>
    </div>
    """
  end

  defp show_join_button?(game, nil), do: false

  defp show_join_button?(game, user) do
    game.state == :open and user.id != game.player_o_id
  end
end
```

- [ ] Verify it compiles:

```bash
mix compile --warnings-as-errors
```

Expected: compiles without warnings.

### Step 2: Commit

- [ ] Commit:

```bash
jj describe -m "Add GameComponents"
jj new
```

---

## Task 6: LobbyLive

Create the lobby LiveView with routing.

**Files:**
- Create: `lib/xo_web/live/lobby_live.ex`
- Modify: `lib/xo_web/router.ex`
- Create: `test/xo_web/live/lobby_live_test.exs`

### Step 1: Write failing LiveView test

- [ ] Create `test/xo_web/live/lobby_live_test.exs`:

```elixir
defmodule XOWeb.LobbyLiveTest do
  use XoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Xo.Generators.User, only: [user: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games

  describe "unauthenticated user" do
    test "can view the lobby", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "XO"
    end

    test "sees open games", %{conn: conn} do
      player = generate(user())
      Games.create_game!(actor: player)

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ player.name
    end

    test "does not see create game button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      refute html =~ "New Game"
    end
  end

  describe "authenticated user" do
    setup %{conn: conn} do
      user = generate(user())
      %{conn: log_in(conn, user), user: user}
    end

    test "sees create game button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "New Game"
    end

    test "can create a game", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("button", "New Game")
      |> render_click()

      assert_redirect(view, ~r"/games/\\d+")
    end

    test "can join an open game", %{conn: conn, user: user} do
      creator = generate(user())
      game = Games.create_game!(actor: creator)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("button[phx-value-game-id='#{game.id}']", "Join")
      |> render_click()

      assert_redirect(view, "/games/#{game.id}")
    end
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
```

- [ ] Run to verify it fails:

```bash
mix test test/xo_web/live/lobby_live_test.exs --max-failures 1
```

Expected: error — no route or module.

### Step 2: Create LobbyLive and update router

- [ ] Create `lib/xo_web/live/lobby_live.ex`:

```elixir
defmodule XOWeb.LobbyLive do
  use XoWeb, :live_view

  on_mount {XoWeb.LiveUserAuth, :live_user_optional}

  import XOWeb.GameUI
  import XOWeb.LobbyComponents

  alias Xo.Games

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xo.PubSub, "game:lobby")
    end

    socket =
      socket
      |> assign(:page_title, "Lobby")
      |> load_games()

    {:ok, socket}
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, put_flash(socket, :error, "You must be signed in to create a game")}

      user ->
        game = Games.create_game!(actor: user)
        {:noreply, push_navigate(socket, to: ~p"/games/#{game.id}")}
    end
  end

  def handle_event("join_game", %{"game-id" => game_id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, put_flash(socket, :error, "You must be signed in to join a game")}

      user ->
        game = Games.get_by_id!(game_id)
        Games.join!(game, actor: user)
        {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    {:noreply, load_games(socket)}
  end

  defp load_games(socket) do
    open_games =
      Games.list_open_games!(load: [:player_o, :state, :move_count])

    active_games =
      Games.list_active_games!(load: [:player_o, :player_x, :state, :move_count, :next_player_id])

    socket
    |> assign(:open_games, open_games)
    |> assign(:active_games, active_games)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="XO">
      <:actions>
        <button :if={@current_user} phx-click="create_game" class="btn btn-primary btn-sm">
          New Game
        </button>
      </:actions>
    </.page_header>

    <.section title="Open Games">
      <%= if @open_games == [] do %>
        <.empty_state message="No open games yet" />
      <% else %>
        <.games_list games={@open_games} current_user={@current_user} variant={:open} />
      <% end %>
    </.section>

    <.section title="Active Games">
      <%= if @active_games == [] do %>
        <.empty_state message="No active games" />
      <% else %>
        <.games_list games={@active_games} current_user={@current_user} variant={:active} />
      <% end %>
    </.section>
    """
  end
end
```

- [ ] Update `lib/xo_web/router.ex`. Inside the `ash_authentication_live_session :authenticated_routes do` block, add the live routes:

```elixir
ash_authentication_live_session :authenticated_routes do
  live "/", LobbyLive
  live "/games/:id", GameLive
end
```

Also remove the old `get "/", PageController, :home` line from the second scope block (the one at line 44).

### Step 3: Run LobbyLive tests

- [ ] Run:

```bash
mix test test/xo_web/live/lobby_live_test.exs --max-failures 1
```

Fix any issues. The `log_in/2` helper may need adjusting depending on how `ash_authentication_live_session` reads the session. If `store_in_session` is not available, use:

```elixir
defp log_in(conn, user) do
  conn
  |> Phoenix.ConnTest.init_test_session(%{})
  |> AshAuthentication.Phoenix.Plug.store_in_session(user)
end
```

- [ ] Run until all tests pass:

```bash
mix test test/xo_web/live/lobby_live_test.exs
```

Expected: all PASS

### Step 4: Commit

- [ ] Commit:

```bash
jj describe -m "Add LobbyLive with routing and tests"
jj new
```

---

## Task 7: GameLive

Create the game page LiveView.

**Files:**
- Create: `lib/xo_web/live/game_live.ex`
- Create: `test/xo_web/live/game_live_test.exs`

### Step 1: Write failing LiveView tests

- [ ] Create `test/xo_web/live/game_live_test.exs`:

```elixir
defmodule XOWeb.GameLiveTest do
  use XoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Xo.Generators.User, only: [user: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games

  defp create_active_game do
    player_o = generate(user())
    player_x = generate(user())
    game = Games.create_game!(actor: player_o)
    game = Games.join!(game, actor: player_x)
    %{game: game, player_o: player_o, player_x: player_x}
  end

  defp log_in(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Phoenix.Plug.store_in_session(user)
  end

  describe "viewing a game" do
    test "spectator can view an active game", %{conn: conn} do
      %{game: game} = create_active_game()

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "Game ##{game.id}"
      assert html =~ "Spectating"
    end

    test "player_o sees their role", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "You are O"
    end

    test "shows board cells", %{conn: conn} do
      %{game: game} = create_active_game()

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      # 9 board cells should be rendered
      assert html =~ "make_move" or html =~ "board"
    end

    test "shows status banner", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "Your turn"
    end
  end

  describe "making moves" do
    test "player can click a cell to make a move", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      html =
        view
        |> element("button[phx-value-field='4']")
        |> render_click()

      assert html =~ "O"
    end

    test "spectator cannot make moves", %{conn: conn} do
      %{game: game} = create_active_game()

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      # No clickable cells for spectator
      refute html =~ ~s(phx-click="make_move")
    end
  end

  describe "joining a game" do
    test "player can join an open game", %{conn: conn} do
      creator = generate(user())
      game = Games.create_game!(actor: creator)
      joiner = generate(user())
      conn = log_in(conn, joiner)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      html =
        view
        |> element("button", "Join Game")
        |> render_click()

      assert html =~ "You are X"
    end
  end

  describe "real-time updates" do
    test "board updates when opponent moves", %{conn: conn} do
      %{game: game, player_o: player_o, player_x: player_x} = create_active_game()
      conn = log_in(conn, player_x)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      # player_o makes a move outside the LiveView
      Games.make_move!(game, 0, actor: player_o)

      # The view should update via PubSub
      html = render(view)
      assert html =~ "O"
    end
  end
end
```

- [ ] Run to verify it fails:

```bash
mix test test/xo_web/live/game_live_test.exs --max-failures 1
```

Expected: error — module not found.

### Step 2: Create GameLive

- [ ] Create `lib/xo_web/live/game_live.ex`:

```elixir
defmodule XOWeb.GameLive do
  use XoWeb, :live_view

  on_mount {XoWeb.LiveUserAuth, :live_user_optional}

  import XOWeb.GameUI
  import XOWeb.GameComponents

  alias Xo.Games
  alias XOWeb.GamePresenter

  @game_loads [
    :state,
    :board,
    :available_fields,
    :next_player_id,
    :winner_id,
    :move_count,
    :player_o,
    :player_x
  ]

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xo.PubSub, "game:#{game_id}")
    end

    game = Games.get_by_id!(game_id, load: @game_loads)
    socket = assign_game_data(socket, game)

    {:ok, socket}
  end

  @impl true
  def handle_event("make_move", %{"field" => field_str}, socket) do
    field = String.to_integer(field_str)
    user = socket.assigns.current_user
    game = socket.assigns.game

    case Games.make_move(game, field, actor: user) do
      {:ok, _game} ->
        {:noreply, socket}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not make that move")}
    end
  end

  def handle_event("join_game", _params, socket) do
    user = socket.assigns.current_user
    game = socket.assigns.game

    case Games.join(game, actor: user) do
      {:ok, _game} ->
        {:noreply, socket}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not join game")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    game = Games.get_by_id!(socket.assigns.game.id, load: @game_loads)
    {:noreply, assign_game_data(socket, game)}
  end

  defp assign_game_data(socket, game) do
    user = socket.assigns.current_user
    role = GamePresenter.role(game, user)

    socket
    |> assign(:game, game)
    |> assign(:role, role)
    |> assign(:clickable_fields, GamePresenter.clickable_fields(game, user))
    |> assign(:status_text, GamePresenter.status_text(game, user))
    |> assign(:page_title, "Game ##{game.id}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title={"Game ##{@game.id}"}>
      <:actions>
        <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
          ← Lobby
        </.link>
      </:actions>
    </.page_header>

    <.game_status_banner status_text={@status_text} />

    <div class="flex flex-col md:flex-row gap-6">
      <div class="flex-1">
        <.board board={@game.board} clickable_fields={@clickable_fields} />
      </div>
      <div class="w-full md:w-64 flex flex-col gap-4">
        <.game_header game={@game} role={@role} />
        <.players_panel game={@game} role={@role} current_user={@current_user} />
        <.action_bar game={@game} role={@role} current_user={@current_user} />
      </div>
    </div>
    """
  end
end
```

### Step 3: Run GameLive tests

- [ ] Run:

```bash
mix test test/xo_web/live/game_live_test.exs --max-failures 1
```

Fix issues as they appear. Common issues:
- The non-bang `Games.make_move/3` and `Games.join/2` variants should work automatically since Ash defines both bang and non-bang versions for each `define`. If they don't exist, the GameLive code uses `case` on the return value — the non-bang versions return `{:ok, result}` or `{:error, error}`.

- [ ] Run until all tests pass:

```bash
mix test test/xo_web/live/game_live_test.exs
```

Expected: all PASS

### Step 4: Commit

- [ ] Commit:

```bash
jj describe -m "Add GameLive with board, moves, and real-time updates"
jj new
```

---

## Task 8: Integration & Full Test Suite

Run all tests, fix any issues, verify in browser.

**Files:**
- No new files

### Step 1: Run the full test suite

- [ ] Run:

```bash
mix test
```

Fix any failures. Common issues:
- The old `page_controller_test.exs` may fail because the `/` route changed. Update or remove it.
- Compilation warnings from unused variables.

### Step 2: Fix the page controller test

- [ ] The test in `test/xo_web/controllers/page_controller_test.exs` tests `GET /` which now routes to LobbyLive instead of PageController. Either:

(a) Delete the file if it only tests the home page, or
(b) Update the test to expect a LiveView response:

```elixir
defmodule XoWeb.PageControllerTest do
  use XoWeb.ConnCase, async: true

  test "GET / renders the lobby", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "XO"
  end
end
```

### Step 3: Run full suite again

- [ ] Run:

```bash
mix test
```

Expected: all PASS

### Step 4: Verify in browser

- [ ] Open `http://localhost:4000/` — should show the lobby
- [ ] The lobby should display "Open Games" and "Active Games" sections
- [ ] The "New Game" button should only appear when signed in

### Step 5: Commit

- [ ] Commit:

```bash
jj describe -m "Fix integration issues and update existing tests"
jj new
```

---

## Task 9: Layout Update

Update the app layout to work well with the new game pages.

**Files:**
- Modify: `lib/xo_web/components/layouts.ex`

### Step 1: Update the app layout

- [ ] In `lib/xo_web/components/layouts.ex`, update the `app/1` function to be more suitable for the game app. Replace the placeholder Phoenix links with game-relevant navigation:

```elixir
def app(assigns) do
  ~H"""
  <header class="navbar px-4 sm:px-6 lg:px-8">
    <div class="flex-1">
      <a href="/" class="flex items-center gap-2">
        <span class="text-xl font-bold">XO</span>
      </a>
    </div>
    <div class="flex-none">
      <ul class="flex flex-column px-1 space-x-4 items-center">
        <li :if={@current_scope}>
          <span class="text-sm text-base-content/60">{@current_scope.email}</span>
        </li>
        <li>
          <.theme_toggle />
        </li>
      </ul>
    </div>
  </header>

  <main class="px-4 py-8 sm:px-6 lg:px-8">
    <div class="mx-auto max-w-3xl">
      {render_slot(@inner_block)}
    </div>
  </main>

  <.flash_group flash={@flash} />
  """
end
```

Note: `@current_scope` is set by `ash_authentication_live_session`. Check if it provides the user's email or if you need `@current_user` instead. If `current_scope` is not available, use `@current_user` and conditionally display `@current_user.email`.

### Step 2: Verify

- [ ] Run:

```bash
mix test
```

- [ ] Check in browser that the layout looks clean.

### Step 3: Commit

- [ ] Commit:

```bash
jj describe -m "Update app layout for game pages"
jj new
```

---

## Summary

| Task | Description | Key Files |
|---|---|---|
| 1 | Ash domain changes | game.ex, games.ex |
| 2 | GamePresenter | game_presenter.ex |
| 3 | GameUI layout components | game_ui.ex |
| 4 | LobbyComponents | lobby_components.ex |
| 5 | GameComponents | game_components.ex |
| 6 | LobbyLive + routing | lobby_live.ex, router.ex |
| 7 | GameLive | game_live.ex |
| 8 | Integration & full test suite | fix existing tests |
| 9 | Layout update | layouts.ex |

Tasks 1-2 must be done first (domain + presenter are dependencies). Tasks 3-5 (components) can be done in parallel. Tasks 6-7 (LiveViews) depend on components and presenter. Task 8-9 are final cleanup.
