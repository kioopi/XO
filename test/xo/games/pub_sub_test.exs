defmodule Xo.Games.PubSubTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games

  defp subscribe(topic) do
    Phoenix.PubSub.subscribe(Xo.PubSub, topic)
  end

  defp assert_notification(action_name) do
    event = to_string(action_name)

    assert_receive %Phoenix.Socket.Broadcast{
      event: ^event,
      payload: %Ash.Notifier.Notification{}
    }
  end

  defp assert_notification_with_loads(action_name) do
    event = to_string(action_name)

    assert_receive %Phoenix.Socket.Broadcast{
      event: ^event,
      payload: %Ash.Notifier.Notification{data: data}
    }

    data.calculations
  end

  defp refute_notification do
    refute_receive %Phoenix.Socket.Broadcast{}
  end

  describe "create publishes to lobby" do
    test "publishes to game:created with state and player_o loaded" do
      subscribe("game:created")

      player = generate(user())
      Games.create_game!(actor: player)

      calcs = assert_notification_with_loads(:create)
      assert calcs[:state] == :open
    end

    test "does not publish to game:<id> on create" do
      player = generate(user())
      game = Games.create_game!(actor: player)

      subscribe("game:#{game.id}")

      refute_notification()
    end
  end

  describe "join publishes to lobby and game view" do
    test "publishes to game:activity:<id> for lobby" do
      player_o = generate(user())
      game = Games.create_game!(actor: player_o)

      subscribe("game:activity:#{game.id}")

      player_x = generate(user())
      Games.join!(game, actor: player_x)

      assert_notification(:join)
    end

    test "publishes to game:<id> with game state loaded" do
      player_o = generate(user())
      game = Games.create_game!(actor: player_o)

      subscribe("game:#{game.id}")

      player_x = generate(user())
      Games.join!(game, actor: player_x)

      calcs = assert_notification_with_loads(:join)
      assert calcs[:state] == :active
      assert is_list(calcs[:board])
    end
  end

  describe "make_move publishes to game view" do
    setup do
      player_o = generate(user())
      player_x = generate(user())

      game =
        Games.create_game!(actor: player_o)
        |> Games.join!(actor: player_x)

      %{game: game, player_o: player_o, player_x: player_x}
    end

    test "publishes to game:<id> with board and state", %{
      game: game,
      player_o: player_o
    } do
      subscribe("game:#{game.id}")

      Games.make_move!(game, 4, actor: player_o)

      calcs = assert_notification_with_loads(:make_move)
      assert calcs[:state] == :active
      assert is_list(calcs[:board])
      assert Enum.at(calcs[:board], 4) == :o
      assert is_list(calcs[:available_fields])
      refute 4 in calcs[:available_fields]
    end

    test "does not publish to game:activity:<id> on move", %{
      game: game,
      player_o: player_o
    } do
      subscribe("game:activity:#{game.id}")

      Games.make_move!(game, 0, actor: player_o)

      refute_notification()
    end

    test "winning move includes winner_id", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      subscribe("game:#{game.id}")

      # O wins top row: 0, 1, 2
      game = Games.make_move!(game, 0, actor: player_o)
      assert_notification(:make_move)

      game = Games.make_move!(game, 3, actor: player_x)
      assert_notification(:make_move)

      game = Games.make_move!(game, 1, actor: player_o)
      assert_notification(:make_move)

      game = Games.make_move!(game, 4, actor: player_x)
      assert_notification(:make_move)

      Games.make_move!(game, 2, actor: player_o)

      calcs = assert_notification_with_loads(:make_move)
      assert calcs[:state] == :won
      assert calcs[:winner_id] == player_o.id
    end

    test "draw game includes draw state", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      subscribe("game:#{game.id}")

      # Play to draw: O X O / O X X / X O O
      game = Games.make_move!(game, 0, actor: player_o)
      assert_notification(:make_move)
      game = Games.make_move!(game, 1, actor: player_x)
      assert_notification(:make_move)
      game = Games.make_move!(game, 2, actor: player_o)
      assert_notification(:make_move)
      game = Games.make_move!(game, 4, actor: player_x)
      assert_notification(:make_move)
      game = Games.make_move!(game, 3, actor: player_o)
      assert_notification(:make_move)
      game = Games.make_move!(game, 5, actor: player_x)
      assert_notification(:make_move)
      game = Games.make_move!(game, 7, actor: player_o)
      assert_notification(:make_move)
      game = Games.make_move!(game, 6, actor: player_x)
      assert_notification(:make_move)
      Games.make_move!(game, 8, actor: player_o)

      calcs = assert_notification_with_loads(:make_move)
      assert calcs[:state] == :draw
      assert is_nil(calcs[:winner_id])
    end
  end

  describe "lobby topic" do
    test "create publishes to game:lobby" do
      subscribe("game:lobby")

      player = generate(user())
      Games.create_game!(actor: player)

      assert_notification(:create)
    end

    test "join publishes to game:lobby" do
      player_o = generate(user())
      game = Games.create_game!(actor: player_o)

      subscribe("game:lobby")

      player_x = generate(user())
      Games.join!(game, actor: player_x)

      assert_notification(:join)
    end

    test "destroy publishes to game:lobby" do
      player = generate(user())
      game = Games.create_game!(actor: player)

      subscribe("game:lobby")

      Ash.destroy!(game, authorize?: false)

      assert_notification(:destroy)
    end
  end

  describe "destroy publishes to both topics" do
    test "publishes to game:activity:<id>" do
      player = generate(user())
      game = Games.create_game!(actor: player)

      subscribe("game:activity:#{game.id}")

      Ash.destroy!(game, authorize?: false)

      assert_notification(:destroy)
    end

    test "publishes to game:<id>" do
      player = generate(user())
      game = Games.create_game!(actor: player)

      subscribe("game:#{game.id}")

      Ash.destroy!(game, authorize?: false)

      assert_notification(:destroy)
    end
  end
end
