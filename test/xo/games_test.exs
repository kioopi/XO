defmodule Xo.GamesTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]

  import Ash.Generator, only: [generate: 1]

  alias Xo.Games

  describe "create_game" do
    test "creates a game with actor as player_o" do
      player = generate(user())
      game = Games.create_game!(actor: player)

      assert game.player_o_id == player.id
    end

    test "game starts in open state" do
      player = generate(user())
      game = Games.create_game!(actor: player, load: [:state])

      assert game.state == :open
    end

    test "fails without an actor" do
      assert_raise Ash.Error.Invalid, fn ->
        Games.create_game!(authorize?: true)
      end
    end
  end

  describe "list_open_games" do
    test "returns empty list when no games exist" do
      assert Games.list_open_games!() == []
    end

    test "returns only open games" do
      player_o = generate(user())
      player_x = generate(user())

      open_game = Games.create_game!(actor: player_o)

      _active_game =
        Games.create_game!(actor: generate(user()))
        |> Games.join!(actor: player_x)

      games = Games.list_open_games!()

      assert length(games) == 1
      assert hd(games).id == open_game.id
    end
  end

  describe "get_by_id" do
    test "returns game by id" do
      player = generate(user())
      game = Games.create_game!(actor: player)

      found = Games.get_by_id!(game.id)

      assert found.id == game.id
    end

    test "raises for nonexistent id" do
      assert_raise Ash.Error.Invalid, fn ->
        Games.get_by_id!(999_999)
      end
    end

    test "supports load option" do
      player = generate(user())
      game = Games.create_game!(actor: player)

      found = Games.get_by_id!(game.id, load: [:state])

      assert found.state == :open
    end
  end

  describe "join" do
    test "joins as player_x and transitions to active" do
      player_o = generate(user())
      player_x = generate(user())

      game = Games.create_game!(actor: player_o)
      game = Games.join!(game, actor: player_x, load: [:state])

      assert game.player_x_id == player_x.id
      assert game.state == :active
    end

    test "fails when actor is same as player_o" do
      player = generate(user())
      game = Games.create_game!(actor: player)

      assert_raise Ash.Error.Forbidden, fn ->
        Games.join!(game, actor: player)
      end
    end

    test "fails when game already has player_x" do
      player_o = generate(user())
      game = Games.create_game!(actor: player_o)
      Games.join!(game, actor: generate(user()))

      assert_raise Ash.Error.Invalid, fn ->
        Games.join!(game, actor: generate(user()))
      end
    end
  end

  describe "make_move" do
    setup do
      player_o = generate(user())
      player_x = generate(user())

      game =
        Games.create_game!(actor: player_o)
        |> Games.join!(actor: player_x)

      %{game: game, player_o: player_o, player_x: player_x}
    end

    test "player_o makes first move", %{game: game, player_o: player_o} do
      game = Games.make_move!(game, 0, actor: player_o)

      assert game
    end

    test "alternating moves work", %{game: game, player_o: player_o, player_x: player_x} do
      game = Games.make_move!(game, 0, actor: player_o)
      game = Games.make_move!(game, 1, actor: player_x)
      game = Games.make_move!(game, 2, actor: player_o)

      assert game
    end

    test "fails when not actor's turn", %{game: game, player_x: player_x} do
      assert_raise Ash.Error.Forbidden, fn ->
        Games.make_move!(game, 0, actor: player_x)
      end
    end

    test "fails for stranger", %{game: game} do
      stranger = generate(user())

      assert_raise Ash.Error.Forbidden, fn ->
        Games.make_move!(game, 0, actor: stranger)
      end
    end
  end

  describe "full game flow" do
    test "play a complete game through the code interface" do
      player_o = generate(user())
      player_x = generate(user())

      # Create a game
      game = Games.create_game!(actor: player_o)

      # Game appears in open games
      open = Games.list_open_games!()
      assert Enum.any?(open, &(&1.id == game.id))

      # Join the game
      game = Games.join!(game, actor: player_x)

      # Game no longer appears in open games
      open = Games.list_open_games!()
      refute Enum.any?(open, &(&1.id == game.id))

      # Play to a win: O wins top row (0, 1, 2)
      game = Games.make_move!(game, 0, actor: player_o)
      game = Games.make_move!(game, 3, actor: player_x)
      game = Games.make_move!(game, 1, actor: player_o)
      game = Games.make_move!(game, 4, actor: player_x)
      game = Games.make_move!(game, 2, actor: player_o, load: [:state, :winner_id])

      assert game.state == :won
      assert game.winner_id == player_o.id

      # Cannot move after game is won
      assert_raise Ash.Error.Invalid, fn ->
        Games.make_move!(game, 5, actor: player_x)
      end
    end
  end
end
