# Xo Presentation Slide Deck — Structure Design

## Context

The Xo project demonstrates Ash Framework's declarative programming model through a tic-tac-toe game with progressive complexity. This spec defines the narrative structure for a ~40-minute presentation aimed at experienced developers who know some Elixir but not Ash. The goal: they understand Ash's model, see its strengths, and want to try it.

Format: Markdown slide deck with key code snippets on slides, supplemented by switching to the editor for walkthroughs. Informal, conversational tone.

## Structure: "The Growing Domain"

Three-act structure with a bookend framing. The thesis — "Model your domain, derive the rest" — is introduced as a promise in the opening and proven through each act. Each act ends with a "derive" beat showing what Ash gave for free.

---

## Opening (~5 min, 4-5 slides)

1. **Title** — "Xo: Tic-Tac-Toe with Ash Framework"
2. **What is Ash?** — A declarative, extensible framework for Elixir applications. Sits below Phoenix — not a web framework, a domain modeling framework.
3. **"Model your domain, derive the rest"** — The thesis. You describe *what* your app does (resources, actions, relationships). Ash handles the *how* (authorization, validation, queries, forms, PubSub, admin...).
4. **The Ash ecosystem** — Visual: Ash core at center, extensions radiating out (AshPostgres, AshPhoenix, AshAuthentication, AshAi, AshAdmin...). Brief mention of Spark (DSL engine) and Igniter (code generation).
5. **The project** — "Let's build a tic-tac-toe game and see how far declarations take us."

---

## Act 1 — The Core Game (~15 min, 10-12 slides)

Two beats: "Model your domain" then "Derive the rest" — making the thesis concrete for the first time.

### Beat 1: Model your domain (~10 min)

6. **Accounts & AshAuthentication** — Users come from AshAuthentication. Auth is declared, not built. Show the strategies block briefly.
   - File: `lib/xo/accounts/user.ex`

7. **The Game resource — Attributes & Actions** — Attributes are minimal. Actions tell the story: `:create`, `:join`, `:make_move`. "Actions are where behavior lives in Ash."
   - File: `lib/xo/games/game.ex`
   - Switch to editor for walkthrough.

8. **Relationships** — `belongs_to :player_o`, `belongs_to :player_x`, `has_many :moves`. Relationships are queryable, loadable, usable in expressions.

9. **The Move resource & Changesets** — Custom changes: `LoadGame`, `SetMoveNumber`, `CreateMove`. The changeset pipeline: `before_action`, `after_action`, `set_context`. "Changes are composable units of logic."
   - Files: `lib/xo/games/move.ex`, `lib/xo/games/changes/create_move.ex`, `lib/xo/games/move/changes/`

10. **Validations** — `ValidateGameState`, `ValidatePlayerTurn`. Declared on the action, not scattered through controllers.
    - Files: `lib/xo/games/validations/`, `lib/xo/games/move/validations/`

11. **Calculations** — `:board`, `:state`, `:winner_id`, `:next_player_id`, `:available_fields`. Derived from data, never persisted. Show the expression for `:next_player_id`.
    - Files: `lib/xo/games/calculations/`

12. **Aggregates** — `:move_count`, `:player_o_fields`, `:player_x_fields`. Push computation to the database. Calculations use them.

13. **Policies** — Authorization rules declared on the resource. Only the right player can move, only the creator can invite a bot, anyone can read.

### Beat 2: Derive the rest (~5 min)

14. **PubSub — for free** — Show the `pub_sub` block. "I never call `Phoenix.PubSub.broadcast` in domain code." Real-time updates just work.

15. **AshPhoenix Forms** — `form_to_create_message`, `AshPhoenix.Form.validate()`, `.submit()`. Ash generates form changesets that Phoenix understands.
    - File: `lib/xo_web/live/game_live.ex`

16. **The UI payoff** — GameLive is ~150 lines. No business logic in the web layer. GamePresenter is pure functions over Ash data.
    - Files: `lib/xo_web/live/game_live.ex`, `lib/xo_web/game_presenter.ex`

17. **Messages** — `message.ex` is simple. "Adding a new resource is trivial. It immediately gets forms, PubSub, authorization."
    - File: `lib/xo/games/message.ex`

---

## Act 2 — Adding Intelligence: The Commentator (~10 min, 6 slides)

Narrative shift: "We have a working game. Now let's extend it — without touching the existing code."

18. **The premise** — "What if an AI watched the game and commented on it?" Why this is interesting from an Ash perspective: extending an existing domain.

19. **Fragments — extending without modifying** — `Commentator.DomainFragment` and `Commentator.GameFragment`. New actions on Game without opening `game.ex`. Separation of concerns via the DSL.
    - Files: `lib/xo/games/commentator/domain_fragment.ex`, `lib/xo/games/commentator/game_fragment.ex`

20. **AshAi & the prompt** — The `AshAi.Actions.prompt` block. System prompt, tools (`:read_game`, `:read_moves`). "The domain I already modeled becomes queryable by an LLM. My Ash actions are the AI's tools."
    - File: `lib/xo/games/commentator/game_fragment.ex`

21. **The GenServer bridge** — `Commentator.Server` subscribes to PubSub, reacts to events, dispatches commentary as tasks. "Ash handles the domain. OTP handles the process lifecycle. They compose naturally."
    - File: `lib/xo/games/commentator/server.ex`

22. **Supervision** — Brief: Registry + DynamicSupervisor + TaskSupervisor. Per-game commentator process with isolated failure.
    - File: `lib/xo/games/commentator/supervisor.ex`

23. **The derive beat** — "I added AI commentary. The existing Game resource, its actions, its PubSub — all reused. The commentator posts through the same Message resource. The chat UI didn't change."

---

## Act 3 — Stretching the Model: The Bot Player (~7 min, 5-6 slides)

Narrative shift: "Ash resources usually map to database tables. But what if they don't?"

24. **The premise** — "We want bot players with different strategies. How do we model hardcoded Elixir modules as Ash resources?"

25. **Ash.DataLayer.Simple & the Strategy resource** — Attributes, manual read action, hardcoded module map. "Ash doesn't care where data comes from. A resource is a resource."
    - File: `lib/xo/games/bot/strategy.ex`

26. **Elixir Behaviours meeting Ash** — `behaviour.ex` with three callbacks. `Random` and `Strategic` implementations. "Plain Elixir modules with a behaviour contract. Ash wraps them as a queryable resource. Both paradigms coexist."
    - Files: `lib/xo/games/bot/behaviour.ex`, `lib/xo/games/bot/strategies/`

27. **Fragments again** — `Bot.GameFragment` adds `:bot_join` to Game. Same pattern as commentator. `JoinGame` change: get bot user, set `player_x_id`, start GenServer in `after_action`.
    - Files: `lib/xo/games/bot/game_fragment.ex`, `lib/xo/games/bot/join_game.ex`

28. **Bot.Server** — Subscribes to PubSub, calls `strategy.select_move/1`, makes moves through the same `Games.make_move!`. "The bot uses the exact same API as a human player."
    - File: `lib/xo/games/bot/server.ex`

29. **The derive beat** — "Three features — core game, AI commentator, bot player — all built on the same domain model. Same actions, same PubSub, same authorization. The lobby just needed a dropdown."

---

## Closing (~3 min, 3-4 slides)

30. **The big picture** — Circle back to the thesis. Tally what came for free vs what was actually written. Resource definitions and a few custom changes yielded authorization, PubSub, forms, real-time UI, AI tool interface, admin.

31. **The extensibility story** — "Three features, none required rewriting what came before. Fragments kept concerns separated. The same actions served humans, bots, and AI. This is what a strong domain model buys you — not just at the start, but months into the project."

32. **The ecosystem** — What we didn't cover: AshAdmin, AshGraphql, AshJsonApi, AshStateMachine... "The same domain can derive a GraphQL API, a JSON API, an admin panel." Mention the community.

33. **Call to action** — Links: ash-hq.org, the Xo repo, Discord. "Try it. Model a small domain. See what Ash derives for you."

---

## Estimated Slide Count

~30-34 slides for ~40 minutes. Roughly 1-1.5 minutes per slide, with editor switches adding natural pauses.

## Recurring "Derive" Pattern

Each act follows the same rhythm:
1. Show the domain declarations (the "model" beat)
2. Show what Ash gave for free (the "derive" beat)

This repetition reinforces the thesis and builds cumulative evidence. By Act 3's derive beat, the audience has seen the pattern three times and should be convinced.
