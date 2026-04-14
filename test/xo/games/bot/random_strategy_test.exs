defmodule Xo.Games.Bot.Strategies.RandomTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games.Bot.Strategies.Random

  describe "info/0" do
    test "returns strategy metadata" do
      info = Random.info()

      assert info.key == :random
      assert is_binary(info.name)
      assert is_binary(info.description)
    end
  end

  describe "bot_email/0" do
    test "returns a bot email" do
      assert Random.bot_email() == "random-bot@xo.bot"
    end
  end

  describe "select_move/1" do
    test "returns an available field" do
      player_o = generate(user())
      player_x = generate(user())

      game =
        generate(game(actor: player_o))
        |> Ash.update!(%{}, action: :join, actor: player_x, authorize?: true)

      {:ok, field} = Random.select_move(game)

      assert field in 0..8
    end

    test "returns a field not already taken" do
      player_o = generate(user())
      player_x = generate(user())

      game =
        generate(game(actor: player_o))
        |> Ash.update!(%{}, action: :join, actor: player_x, authorize?: true)

      # O plays center
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Random.select_move(game)

      available = Ash.load!(game, :available_fields).available_fields
      assert field in available
      refute field == 4
    end
  end
end
