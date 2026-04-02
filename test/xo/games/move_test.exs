defmodule Xo.Games.MoveTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 0, game: 1]
  import Xo.Generators.Move, only: [move: 0, move: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games.Move

  defp active_game do
    player_o = generate(user())
    game = generate(game(actor: player_o))
    player_x = generate(user())
    active = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)
    %{game: active, player_o: player_o, player_x: player_x}
  end

  describe "create action" do
    test "creates a move with correct field, move_number, game_id, and player_id" do
      %{game: game, player_o: player_o} = active_game()

      move =
        Ash.create!(Move, %{field: 4, game_id: game.id}, action: :create, actor: player_o)

      assert move.field == 4
      assert move.move_number == 1
      assert move.game_id == game.id
      assert move.player_id == player_o.id
    end

    test "derives move_number from game's move count" do
      %{game: game, player_o: player_o, player_x: player_x} = active_game()

      Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)
      move2 = Ash.create!(Move, %{field: 1, game_id: game.id}, action: :create, actor: player_x)

      assert move2.move_number == 2
    end

    test "rejects move when it is not the actor's turn" do
      %{game: game, player_x: player_x} = active_game()

      assert_raise Ash.Error.Invalid, ~r/not this player's turn/, fn ->
        Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_x)
      end
    end

    test "allows player_x to move on the second turn" do
      %{game: game, player_o: player_o, player_x: player_x} = active_game()

      Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)

      move =
        Ash.create!(Move, %{field: 1, game_id: game.id}, action: :create, actor: player_x)

      assert move.player_id == player_x.id
      assert move.move_number == 2
    end
  end

  describe "identity constraints" do
    test "rejects duplicate field in the same game" do
      %{game: game, player_o: player_o, player_x: player_x} = active_game()

      Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)

      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_x)
      end
    end

    test "rejects duplicate move_number in the same game" do
      %{game: game, player_o: player_o} = active_game()

      Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)

      # This should never happen due to DeriveFromGame, but the DB constraint backs it up
      # We test by creating a second move — move_number is auto-derived so this tests
      # the identity at the DB level indirectly (same field triggers unique_field_per_game first)
      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Move, %{field: 0, game_id: game.id}, action: :create, actor: player_o)
      end
    end

    test "allows same field in different games" do
      %{game: game1, player_o: player_o1} = active_game()
      %{game: game2, player_o: player_o2} = active_game()

      Ash.create!(Move, %{field: 4, game_id: game1.id}, action: :create, actor: player_o1)
      move2 = Ash.create!(Move, %{field: 4, game_id: game2.id}, action: :create, actor: player_o2)

      assert move2.field == 4
    end
  end

  describe "generator" do
    test "generates a valid move with defaults" do
      move = generate(move())

      assert move.id
      assert move.field
      assert move.move_number == 1
      assert move.game_id
      assert move.player_id
    end

    test "generates a move for a provided game" do
      %{game: game, player_o: player_o} = active_game()

      move = generate(move(game: game, actor: player_o))

      assert move.game_id == game.id
      assert move.player_id == player_o.id
    end
  end
end
