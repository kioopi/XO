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
      game = generate(game()) |> Ash.load!(:state)

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

      updated =
        Ash.update!(game, %{}, action: :join, actor: joiner, authorize?: true)
        |> Ash.load!(:state)

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

      assert_raise Ash.Error.Invalid, fn ->
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

    test "succeeds when actor is player_x", %{game: game, player_o: player_o, player_x: player_x} do
      game = Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)
      assert Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)
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

    test "creates a Move record", %{game: game, player_o: player_o} do
      Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)

      [move] = Ash.read!(Xo.Games.Move)
      assert move.field == 4
      assert move.move_number == 1
      assert move.game_id == game.id
      assert move.player_id == player_o.id
    end

    test "creates moves with alternating players", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game =
        Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)

      Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)

      moves = Ash.read!(Xo.Games.Move) |> Enum.sort_by(& &1.move_number)
      assert length(moves) == 2
      assert Enum.at(moves, 0).player_id == player_o.id
      assert Enum.at(moves, 0).move_number == 1
      assert Enum.at(moves, 1).player_id == player_x.id
      assert Enum.at(moves, 1).move_number == 2
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

  describe "game state after moves" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    defp play_moves(game, fields, player_o, player_x) do
      Enum.reduce(fields, {game, 0}, fn field, {game, index} ->
        actor = if rem(index, 2) == 0, do: player_o, else: player_x

        game =
          Ash.update!(game, %{field: field}, action: :make_move, actor: actor, authorize?: true)

        {game, index + 1}
      end)
      |> elem(0)
    end

    test "game stays active after non-winning moves", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      # O takes 0, X takes 3
      game =
        play_moves(game, [0, 3], player_o, player_x)
        |> Ash.load!([:state, :winner_id])

      assert game.state == :active
      assert game.winner_id == nil
    end

    test "player_o wins with top row", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      # O: 0, 1, 2 (top row)
      # X: 3, 4
      game =
        play_moves(game, [0, 3, 1, 4, 2], player_o, player_x)
        |> Ash.load!([:state, :winner_id])

      assert game.state == :won
      assert game.winner_id == player_o.id
    end

    test "player_x wins with left column", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      # O: 1, 4, 8
      # X: 0, 3, 6 (left column)
      game =
        play_moves(game, [1, 0, 4, 3, 8, 6], player_o, player_x)
        |> Ash.load!([:state, :winner_id])

      assert game.state == :won
      assert game.winner_id == player_x.id
    end

    test "player_o wins with diagonal", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      # O: 0, 4, 8 (diagonal)
      # X: 1, 2
      game =
        play_moves(game, [0, 1, 4, 2, 8], player_o, player_x)
        |> Ash.load!([:state, :winner_id])

      assert game.state == :won
      assert game.winner_id == player_o.id
    end

    test "game ends in a draw when board is full with no winner", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      # O: 0, 2, 3, 7, 8
      # X: 1, 4, 5, 6
      # Board:
      # O | X | O
      # O | X | X
      # X | O | O
      game =
        play_moves(game, [0, 1, 2, 4, 3, 5, 7, 6, 8], player_o, player_x)
        |> Ash.load!([:state, :winner_id])

      assert game.state == :draw
      assert game.winner_id == nil
    end

    test "cannot make move after game is won", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      # O wins with top row
      game = play_moves(game, [0, 3, 1, 4, 2], player_o, player_x)
      assert Ash.load!(game, :state).state == :won

      assert_raise Ash.Error.Invalid, fn ->
        Ash.update!(game, %{field: 5}, action: :make_move, actor: player_x, authorize?: true)
      end
    end

    test "cannot make move after draw", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game = play_moves(game, [0, 1, 2, 4, 3, 5, 7, 6, 8], player_o, player_x)
      assert Ash.load!(game, :state).state == :draw

      assert_raise Ash.Error.Invalid, fn ->
        Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)
      end
    end
  end

  describe "calculations after moves" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "next_move_number increments after each move", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game = Ash.load!(game, [:next_move_number])
      assert game.next_move_number == 1

      game =
        Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)

      game = Ash.load!(game, [:next_move_number])
      assert game.next_move_number == 2

      game =
        Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)

      game = Ash.load!(game, [:next_move_number])
      assert game.next_move_number == 3
    end

    test "next_player_id alternates between players", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game = Ash.load!(game, [:next_player_id])
      assert game.next_player_id == player_o.id

      game =
        Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)

      game = Ash.load!(game, [:next_player_id])
      assert game.next_player_id == player_x.id

      game =
        Ash.update!(game, %{field: 1}, action: :make_move, actor: player_x, authorize?: true)

      game = Ash.load!(game, [:next_player_id])
      assert game.next_player_id == player_o.id
    end
  end

  describe "board calculation" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "empty board is all nils", %{game: game} do
      game = Ash.load!(game, :board)

      assert game.board == [nil, nil, nil, nil, nil, nil, nil, nil, nil]
    end

    test "shows :o for player_o move", %{game: game, player_o: player_o} do
      game =
        Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)

      game = Ash.load!(game, :board)

      assert game.board == [nil, nil, nil, nil, :o, nil, nil, nil, nil]
    end

    test "shows :o and :x for both players' moves", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game = play_moves(game, [0, 4], player_o, player_x)
      game = Ash.load!(game, :board)

      assert game.board == [:o, nil, nil, nil, :x, nil, nil, nil, nil]
    end

    test "full board has no nils", %{game: game, player_o: player_o, player_x: player_x} do
      game = play_moves(game, [0, 1, 2, 4, 3, 5, 7, 6, 8], player_o, player_x)
      game = Ash.load!(game, :board)

      assert game.board == [:o, :x, :o, :o, :x, :x, :x, :o, :o]
    end
  end

  describe "available_fields calculation" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "all fields available on empty board", %{game: game} do
      game = Ash.load!(game, :available_fields)

      assert Enum.sort(game.available_fields) == [0, 1, 2, 3, 4, 5, 6, 7, 8]
    end

    test "played field is no longer available", %{game: game, player_o: player_o} do
      game =
        Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)

      game = Ash.load!(game, :available_fields)

      assert Enum.sort(game.available_fields) == [0, 1, 2, 3, 5, 6, 7, 8]
    end

    test "multiple played fields are excluded", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game = play_moves(game, [0, 4], player_o, player_x)
      game = Ash.load!(game, :available_fields)

      assert Enum.sort(game.available_fields) == [1, 2, 3, 5, 6, 7, 8]
    end

    test "no fields available on full board", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game = play_moves(game, [0, 1, 2, 4, 3, 5, 7, 6, 8], player_o, player_x)
      game = Ash.load!(game, :available_fields)

      assert game.available_fields == []
    end
  end
end
