defmodule Xo.Games.GameTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 0, game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games.Game

  describe "create action" do
    test "creates a game with actor as player_o" do
      actor = generate(user())
      game = generate(game(actor: actor))

      assert game.player_o_id == actor.id
    end

    test "game starts in open state" do
      game = generate(game())

      assert game.state == :open
    end

    test "fails without an actor" do
      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Game, %{}, action: :create, authorize?: true)
      end
    end
  end

  describe "open read action" do
    test "returns only games without a player_x" do
      player_o = generate(user())
      player_x = generate(user())

      open_game = generate(game(actor: player_o))

      joined_game = generate(game(actor: generate(user())))
      Ash.update!(joined_game, %{}, action: :join, actor: player_x, authorize?: true)

      games = Ash.read!(Game, action: :open)

      assert length(games) == 1
      assert hd(games).id == open_game.id
    end

    test "returns empty list when all games are joined" do
      player_o = generate(user())
      player_x = generate(user())

      game = generate(game(actor: player_o))
      Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      assert Ash.read!(Game, action: :open) == []
    end

    test "returns all open games" do
      game1 = generate(game())
      game2 = generate(game())

      games = Ash.read!(Game, action: :open)
      ids = Enum.map(games, & &1.id) |> Enum.sort()

      assert ids == Enum.sort([game1.id, game2.id])
    end
  end

  describe "join action" do
    test "second user can join an open game as player_x" do
      game = generate(game())
      joiner = generate(user())

      updated = Ash.update!(game, %{}, action: :join, actor: joiner, authorize?: true)

      assert updated.player_x_id == joiner.id
    end

    test "game transitions to active state after join" do
      game = generate(game())
      joiner = generate(user())

      updated = Ash.update!(game, %{}, action: :join, actor: joiner, authorize?: true)

      assert updated.state == :active
    end

    test "fails without an actor" do
      game = generate(game())

      assert_raise Ash.Error.Invalid, fn ->
        Ash.update!(game, %{}, action: :join, authorize?: true)
      end
    end

    test "fails if actor is the same as player_o" do
      actor = generate(user())
      game = generate(game(actor: actor))

      assert_raise Ash.Error.Forbidden, fn ->
        Ash.update!(game, %{}, action: :join, actor: actor, authorize?: true)
      end
    end

    test "fails if player_x is already set" do
      game = generate(game())
      joiner1 = generate(user())
      joiner2 = generate(user())

      Ash.update!(game, %{}, action: :join, actor: joiner1, authorize?: true)

      assert_raise Ash.Error.Forbidden, fn ->
        Ash.update!(game, %{}, action: :join, actor: joiner2, authorize?: true)
      end
    end
  end

  describe "make_move action" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "succeeds when actor is player_o", %{game: game, player_o: player_o} do
      assert Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)
    end

    test "succeeds when actor is player_x", %{game: game, player_x: player_x} do
      assert Ash.update!(game, %{field: 0}, action: :make_move, actor: player_x, authorize?: true)
    end

    test "fails without an actor", %{game: game} do
      assert_raise Ash.Error.Forbidden, fn ->
        Ash.update!(game, %{field: 0}, action: :make_move, authorize?: true)
      end
    end

    test "fails when actor is neither player_o nor player_x", %{game: game} do
      stranger = generate(user())

      assert_raise Ash.Error.Forbidden, fn ->
        Ash.update!(game, %{field: 0}, action: :make_move, actor: stranger, authorize?: true)
      end
    end
  end

  describe "next_move_number calculation" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "returns 1 for a game with no moves", %{game: game} do
      game = Ash.load!(game, :next_move_number)
      assert game.next_move_number == 1
    end
  end

  describe "next_player_id calculation" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "returns player_o_id for a game with no moves", %{game: game, player_o: player_o} do
      game = Ash.load!(game, :next_player_id)
      assert game.next_player_id == player_o.id
    end
  end
end
