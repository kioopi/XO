defmodule Xo.Games.Actions.GenerateCommentaryTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games.Game

  setup do
    player_o = generate(user())
    player_x = generate(user())
    game = generate(game(actor: player_o))
    game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

    %{game: game, player_o: player_o, player_x: player_x}
  end

  describe "generate_commentary action" do
    test "requires an actor", %{game: game} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Game
               |> Ash.ActionInput.for_action(:generate_commentary, %{
                 game_id: game.id,
                 event_description: "A move was made."
               })
               |> Ash.run_action()
    end

    test "dispatches to context path by default", %{game: game, player_o: actor} do
      # With default config (commentator_use_tools: false), the action loads
      # the game, builds context via GameSummary, and delegates to
      # generate_commentary_with_context. The bread crumbs in the error confirm
      # which sub-action was reached.
      error =
        assert_raise Ash.Error.Unknown, fn ->
          Game
          |> Ash.ActionInput.for_action(
            :generate_commentary,
            %{game_id: game.id, event_description: "A move was made."},
            actor: actor
          )
          |> Ash.run_action!()
        end

      assert Exception.message(error) =~ "generate_commentary_with_context"
    end

    test "dispatches to tools path when configured", %{game: game, player_o: actor} do
      Application.put_env(:xo, :commentator_use_tools, true)

      on_exit(fn ->
        Application.put_env(:xo, :commentator_use_tools, false)
      end)

      # With tools enabled, the bread crumbs confirm the tools sub-action was reached.
      error =
        assert_raise Ash.Error.Unknown, fn ->
          Game
          |> Ash.ActionInput.for_action(
            :generate_commentary,
            %{game_id: game.id, event_description: "A move was made."},
            actor: actor
          )
          |> Ash.run_action!()
        end

      assert Exception.message(error) =~ "generate_commentary_with_tools"
    end

    test "fails on non-existent game_id", %{player_o: actor} do
      assert_raise Ash.Error.Invalid, fn ->
        Game
        |> Ash.ActionInput.for_action(
          :generate_commentary,
          %{game_id: -1, event_description: "A move was made."},
          actor: actor
        )
        |> Ash.run_action!()
      end
    end
  end
end
