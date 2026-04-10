# Commentator Feature Reorganization

## Problem

The AI Commentator feature is spread across several locations in the codebase:

- `lib/xo/games/commentator.ex` — GenServer
- `lib/xo/games/commentator_bot.ex` — Bot user manager
- `lib/xo/games/commentator_domain.ex` — Domain fragment
- `lib/xo/games/game/commentator.ex` — Resource fragment
- `lib/xo/games/actions/generate_commentary.ex` — Action implementation
- `lib/xo/games/changes/start_commentator.ex` — Change module

This makes the feature hard to reason about as a unit. All commentator-related code should live together under a common directory and namespace.

## Approach

Co-locate all commentator files under `lib/xo/games/commentator/` with the namespace `Xo.Games.Commentator.*`. The fragments continue to compose into the existing `Xo.Games` domain and `Xo.Games.Game` resource — no new domain is needed since the feature has no resources of its own.

## File Moves

| Current path | New path | New module name |
|---|---|---|
| `lib/xo/games/commentator.ex` | `lib/xo/games/commentator/server.ex` | `Xo.Games.Commentator.Server` |
| `lib/xo/games/commentator_bot.ex` | `lib/xo/games/commentator/bot.ex` | `Xo.Games.Commentator.Bot` |
| `lib/xo/games/commentator_domain.ex` | `lib/xo/games/commentator/domain_fragment.ex` | `Xo.Games.Commentator.DomainFragment` |
| `lib/xo/games/game/commentator.ex` | `lib/xo/games/commentator/game_fragment.ex` | `Xo.Games.Commentator.GameFragment` |
| `lib/xo/games/actions/generate_commentary.ex` | `lib/xo/games/commentator/generate_commentary.ex` | `Xo.Games.Commentator.GenerateCommentary` |
| `lib/xo/games/changes/start_commentator.ex` | `lib/xo/games/commentator/start_commentator.ex` | `Xo.Games.Commentator.StartCommentator` |

## Resulting Structure

```
lib/xo/games/commentator/
├── bot.ex                  # Bot user manager
├── domain_fragment.ex      # Domain fragment (AshAi tools)
├── game_fragment.ex        # Resource fragment (actions/policies)
├── generate_commentary.ex  # Action implementation
├── server.ex               # Per-game GenServer
└── start_commentator.ex    # Change that starts GenServer on join
```

## References to Update

- `Xo.Games` domain (`lib/xo/games.ex`): fragment `__MODULE__.CommentatorDomain` → `Xo.Games.Commentator.DomainFragment`
- `Xo.Games.Game` resource (`lib/xo/games/game.ex`): fragment `__MODULE__.Commentator` → `Xo.Games.Commentator.GameFragment`
- `Xo.Application` (`lib/xo/application.ex`): no changes needed — supervisor child names (`CommentatorRegistry`, `CommentatorSupervisor`, `CommentatorTaskSupervisor`) are process names, not module names
- `start_commentator.ex`: `{Xo.Games.Commentator, game.id}` → `{Xo.Games.Commentator.Server, game.id}`
- `game_fragment.ex`: action implementation `Xo.Games.Actions.GenerateCommentary` → `Xo.Games.Commentator.GenerateCommentary`
- `game_fragment.ex`: change reference `Changes.StartCommentator` → `Xo.Games.Commentator.StartCommentator`
- `server.ex` (GenServer): internal references to `Xo.Games.CommentatorBot` → `Xo.Games.Commentator.Bot`

## What Stays the Same

- Fragments still compose into `Xo.Games` domain and `Xo.Games.Game` resource
- Supervisor children in `application.ex` keep existing process names
- All PubSub subscriptions, event handling, and LLM integration unchanged
- No behavioral changes — this is a pure reorganization

## Verification

1. `mix compile --warnings-as-errors` — confirms no dangling references
2. `mix test` — confirms no behavioral regressions
3. Verify the old files are deleted and no stale modules remain
