# LiveView UI Design

## Overview

Two-page LiveView UI for the XO tic-tac-toe application. The lobby discovers and creates games; the game view shows a single game and accepts player commands. Both pages are accessible to unauthenticated users (spectators). Game controls require authentication.

## Architecture

### LiveViews

| LiveView | Route | Auth | Purpose |
|---|---|---|---|
| `XOWeb.LobbyLive` | `/` | `:live_user_optional` | Discover, create, join games |
| `XOWeb.GameLive` | `/games/:id` | `:live_user_optional` | Play or spectate a single game |

Both live inside the existing `ash_authentication_live_session` block. The current `PageController` home route is replaced.

### Component Modules

| Module | Type | Purpose |
|---|---|---|
| `XOWeb.GameUI` | Function components | Layout primitives: page_header, section, empty_state |
| `XOWeb.LobbyComponents` | Function components | games_list, game_card, game_state_badge |
| `XOWeb.GameComponents` | Function components | board, board_cell, game_header, game_status_banner, players_panel, player_card, action_bar |
| `XOWeb.GamePresenter` | Plain module | UI-facing helpers: role, status text, clickable fields |

No LiveComponents in this iteration.

### File Structure

```
lib/xo_web/live/lobby_live.ex
lib/xo_web/live/game_live.ex
lib/xo_web/components/game_ui.ex
lib/xo_web/components/lobby_components.ex
lib/xo_web/components/game_components.ex
lib/xo_web/game_presenter.ex
```

## Data Flow

### Rules

1. LiveViews load and own page data
2. Function components are stateless — receive assigns, render
3. Events flow upward (component → LiveView), commands flow downward (LiveView → domain)
4. Business rules live in Ash domain, not in components
5. After domain actions, reload from source of truth (or react to PubSub)

### PubSub Topics

| Topic | Publisher Actions | Subscriber | Purpose |
|---|---|---|---|
| `game:created` | `:create` | LobbyLive | New game notification |
| `game:lobby` | `:create`, `:join`, `:destroy` | LobbyLive | All lobby-relevant lifecycle events |
| `game:activity:<game_id>` | `:join`, `:destroy` | (existing, kept) | Per-game activity |
| `game:<game_id>` | `:join`, `:make_move`, `:destroy` | GameLive | Full game state updates |

The `game:lobby` topic is new. LobbyLive subscribes to it and reloads game lists on any message.

## GamePresenter

Plain Elixir module at `lib/xo_web/game_presenter.ex`. No Phoenix dependencies.

### Functions

| Function | Signature | Returns |
|---|---|---|
| `role/2` | `(game, user \| nil)` | `:player_o` \| `:player_x` \| `:spectator` |
| `your_mark/2` | `(game, user \| nil)` | `:o` \| `:x` \| `nil` |
| `clickable_fields/2` | `(game, user \| nil)` | list of integers or `[]` |
| `status_text/2` | `(game, user \| nil)` | human-readable string |
| `winner_name/1` | `(game)` | name string or nil |
| `player_display/2` | `(game, :player_o \| :player_x)` | `%{name, mark, is_turn?, is_winner?, is_you?}` |

### Role Derivation

```
nil user → :spectator
user.id == game.player_o_id → :player_o
user.id == game.player_x_id → :player_x
otherwise → :spectator
```

### Status Text

| State | Role | Text |
|---|---|---|
| `:open` | any | "Waiting for an opponent to join" |
| `:active` | current turn player | "Your turn" |
| `:active` | other player | "{Name} is thinking..." |
| `:active` | spectator | "{Name}'s turn" |
| `:won` | winner | "You won!" |
| `:won` | loser | "{Name} won" |
| `:won` | spectator | "{Name} won!" |
| `:draw` | any | "It's a draw!" |

### Clickable Fields

Returns `game.available_fields` only when:
- `game.state == :active`
- `game.next_player_id == user.id`

Otherwise returns `[]`.

## LobbyLive

### Assigns

| Assign | Source | Type |
|---|---|---|
| `current_user` | `on_mount` | `User \| nil` |
| `open_games` | Domain load + PubSub refresh | `[Game]` |
| `active_games` | Domain load + PubSub refresh | `[Game]` |
| `page_title` | Static | `"Lobby"` |

### Events

| Event | Guard | Action | Result |
|---|---|---|---|
| `"create_game"` | `current_user` present | `Games.create_game!(actor: user)` | Redirect to `/games/:id` |
| `"join_game"` | `current_user` present | `Games.join!(game, actor: user)` | Redirect to `/games/:id` |

### Loading Games

- Open games: `Games.list_open_games!()` with load `[:player_o, :state, :move_count]`
- Active games: `Games.list_active_games!()` with load `[:player_o, :player_x, :state, :move_count, :next_player_id]`

### PubSub

Subscribe to `game:lobby` on connected mount. On any message → reload both game lists.

### Template Composition

```
page_header (title: "XO", actions: create_game button if logged in)
section "Open Games"
  games_list
    game_card per game (with "Join" button if logged in and not creator)
  empty_state if none
section "Active Games"
  games_list
    game_card per game (with "Watch" link)
  empty_state if none
```

## GameLive

### Assigns

| Assign | Source | Type |
|---|---|---|
| `current_user` | `on_mount` | `User \| nil` |
| `game` | Loaded by ID + PubSub refresh | `Game` |
| `role` | `GamePresenter.role/2` | atom |
| `clickable_fields` | `GamePresenter.clickable_fields/2` | `[integer]` |
| `status_text` | `GamePresenter.status_text/2` | string |
| `page_title` | Dynamic | `"Game #42"` |

### Game Loading

Single function loads game with all needed calculations:

```elixir
[:state, :board, :available_fields, :next_player_id, :winner_id, :move_count, :player_o, :player_x]
```

Called on mount and after every PubSub message. All presenter-derived assigns recomputed from fresh game.

### Events

| Event | Guard | Action |
|---|---|---|
| `"make_move"` | user is current turn player | `Games.make_move!(game, field, actor: user)` |
| `"join_game"` | user present, game `:open`, not creator | `Games.join!(game, actor: user)` |

Errors (not your turn, game full, etc.) → flash error message, no crash.

### PubSub

Subscribe to `game:<game_id>` on connected mount. On message → reload game + recompute assigns.

### Template Composition

```
page_header (title: "Game #42", actions: back to lobby link)
game_status_banner (status_text)
responsive layout:
  left/top: board (board, clickable_fields)
  right/bottom:
    players_panel
      player_card for O
      player_card for X (or "Waiting..." placeholder if open)
    action_bar (join button if applicable, back to lobby)
```

### Responsive Layout

- Desktop: board left, panel right (side-by-side)
- Mobile: status → board → players → actions (stacked vertically)

## Function Components

### GameUI (layout primitives)

**`page_header/1`**
- Assigns: `title` (string), optional inner block for actions
- Renders page title with optional action buttons on the right

**`section/1`**
- Assigns: `title` (string), inner block
- Renders section heading with body content

**`empty_state/1`**
- Assigns: `message` (string), optional action slot
- Renders centered empty-state message

### LobbyComponents

**`games_list/1`**
- Assigns: `games` (list), `current_user`, inner block
- Renders list container, iterates games

**`game_card/1`**
- Assigns: `game`, `current_user`
- Shows: creator name, state badge, move count, join/watch button
- Join button shown only when: user is logged in, game is open, user is not creator
- Links to `/games/:id` for active games

**`game_state_badge/1`**
- Assigns: `state` (atom)
- Colored DaisyUI badge: open=info, active=warning, won=success, draw=neutral

### GameComponents

**`board/1`**
- Assigns: `board` (9-element list), `clickable_fields` (list of integers), `disabled` (boolean)
- Renders 3×3 CSS grid
- Delegates each cell to `board_cell/1`

**`board_cell/1`**
- Assigns: `value` (`:o` / `:x` / `nil`), `clickable` (boolean), `index` (integer)
- Renders mark or empty state
- When clickable: `phx-click="make_move"` with `phx-value-field={index}`
- When not clickable: no event attributes
- Minimum 4rem × 4rem for touch targets

**`game_header/1`**
- Assigns: `game`, `role`
- Shows game ID, state badge, role label ("You are O", "Spectating")

**`game_status_banner/1`**
- Assigns: `status_text` (string)
- Prominent status message area

**`players_panel/1`**
- Assigns: `game`, `role`, `current_user`
- Composes two `player_card/1` components (O and X)
- Shows "Waiting for opponent..." placeholder if no player_x

**`player_card/1`**
- Assigns: `player`, `mark` (`:o` / `:x`), `is_turn` (boolean), `is_winner` (boolean), `is_you` (boolean)
- Shows player name, mark, turn/winner/you indicators

**`action_bar/1`**
- Assigns: `game`, `role`, `current_user`
- Join button (if game open + user logged in + not creator)
- Back to lobby link

## Ash Domain Changes

### New read action on Game

```elixir
read :active, filter: expr(state == :active)
```

### New domain definition

```elixir
define :list_active_games, action: :active
```

### New PubSub publish lines on Game

```elixir
publish :create, "lobby"
publish :join, "lobby"
publish :destroy, "lobby"
```

Added alongside existing publish lines. No other domain changes.

## Router Changes

Inside the `ash_authentication_live_session` block (which provides `:live_user_optional`):

```elixir
ash_authentication_live_session :authenticated_routes do
  live "/", LobbyLive
  live "/games/:id", GameLive
end
```

The existing `get "/", PageController, :home` route is removed.

## Styling

- DaisyUI for components: badges, cards, buttons
- Tailwind for layout: CSS grid (board), flexbox, responsive breakpoints
- Mobile-first: stack vertically by default, side-by-side at `md:` breakpoint
- Board cells: square, minimum 4rem, comfortable touch targets
- Theme toggle (existing) continues to work via DaisyUI themes

## Game Mark Convention

- `player_o` creates the game and moves first (even move numbers)
- `player_x` joins and moves second (odd move numbers)
- The board calculation returns `:o` and `:x` atoms — the UI renders these directly as "O" and "X"
- No remapping of marks; the domain is the source of truth

## Not In Scope

- Chat (future iteration, not yet in Ash)
- Spectator presence/count
- Bots
- Rematches
- Create-game options/modal (single button for now)
- Animations or cell highlight transitions
