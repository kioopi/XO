defmodule Xo.Games.Bot.Strategies.StrategicTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games.Bot.Strategies.Strategic

  describe "info/0" do
    test "returns strategy metadata" do
      info = Strategic.info()

      assert info.key == :strategic
      assert is_binary(info.name)
      assert is_binary(info.description)
    end
  end

  describe "bot_email/0" do
    test "returns a bot email" do
      assert Strategic.bot_email() == "strategic-bot@xo.bot"
    end
  end

  describe "select_move/1" do
    setup do
      player_o = generate(user())
      player_x = generate(user())

      game =
        generate(game(actor: player_o))
        |> Ash.update!(%{}, action: :join, actor: player_x, authorize?: true)

      %{game: game, player_o: player_o, player_x: player_x}
    end

    test "prefers center on empty board", %{game: game} do
      {:ok, field} = Strategic.select_move(game)

      assert field == 4
    end

    test "takes winning move when available", %{game: game, player_o: player_o, player_x: player_x} do
      # Bot is player_x. Set up: X has 0 and 1, field 2 wins.
      # O: 4, 3; X: 0, 1
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 0}, action: :make_move, actor: player_x, authorize?: true)
      game = Ash.update!(game, %{field: 3}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)

      # Now it's O's turn, but we test strategic logic from X's perspective
      # Let O move to a non-threatening spot
      game = Ash.update!(game, %{field: 8}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Strategic.select_move(game)

      # X should complete the top row: [0, 1, 2]
      assert field == 2
    end

    test "blocks opponent winning move", %{game: game, player_o: player_o, player_x: player_x} do
      # O has 0 and 1, about to win with 2. X should block.
      # O: 0, 1; X: 4
      game = Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_x, authorize?: true)
      game = Ash.update!(game, %{field: 1}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Strategic.select_move(game)

      # X should block position 2
      assert field == 2
    end

    test "prefers corner when center is taken", %{game: game, player_o: player_o} do
      # O takes center, X should take a corner
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Strategic.select_move(game)

      assert field in [0, 2, 6, 8]
    end

    test "falls back to edge when center and corners taken", %{game: game, player_o: player_o, player_x: player_x} do
      # Fill center and all corners, leave only edges
      game = Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 0}, action: :make_move, actor: player_x, authorize?: true)
      game = Ash.update!(game, %{field: 8}, action: :make_move, actor: player_o, authorize?: true)
      game = Ash.update!(game, %{field: 2}, action: :make_move, actor: player_x, authorize?: true)
      game = Ash.update!(game, %{field: 6}, action: :make_move, actor: player_o, authorize?: true)

      {:ok, field} = Strategic.select_move(game)

      assert field in [1, 3, 5, 7]
    end
  end
end
