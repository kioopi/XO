defmodule Xo.Games.Bot.BotJoinTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games

  describe "bot_join" do
    test "bot joins as player_x" do
      player_o = generate(user())
      game = generate(game(actor: player_o))

      game = Games.bot_join!(game, :random, actor: player_o, load: [:state])
      player_x = Ash.get!(Xo.Accounts.User, game.player_x_id, authorize?: false)

      assert game.state == :active
      assert to_string(player_x.email) == "random-bot@xo.bot"
    end

    test "works with strategic strategy" do
      player_o = generate(user())
      game = generate(game(actor: player_o))

      game = Games.bot_join!(game, :strategic, actor: player_o)
      player_x = Ash.get!(Xo.Accounts.User, game.player_x_id, authorize?: false)

      assert to_string(player_x.email) == "strategic-bot@xo.bot"
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

    @tag :skip
    test "starts a Bot.Server process" do
      # Will be unskipped in Task 6 when Bot.Server exists
    end
  end
end
