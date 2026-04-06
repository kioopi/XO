defmodule Xo.Games.MessageTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games
  alias Xo.Games.Message

  defp active_game do
    player_o = generate(user())
    player_x = generate(user())
    game = Games.create_game!(actor: player_o)
    game = Games.join!(game, actor: player_x)
    %{game: game, player_o: player_o, player_x: player_x}
  end

  describe "create action" do
    test "creates a message with body, game_id, and user_id" do
      %{game: game, player_o: player} = active_game()

      message =
        Ash.create!(Message, %{body: "hello", game_id: game.id},
          action: :create,
          actor: player,
          authorize?: true
        )

      assert message.body == "hello"
      assert message.game_id == game.id
      assert message.user_id == player.id
    end

    test "spectator can send a message" do
      %{game: game} = active_game()
      spectator = generate(user())

      message =
        Ash.create!(Message, %{body: "go team!", game_id: game.id},
          action: :create,
          actor: spectator,
          authorize?: true
        )

      assert message.user_id == spectator.id
    end

    test "rejects message without a body" do
      %{game: game, player_o: player} = active_game()

      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Message, %{game_id: game.id},
          action: :create,
          actor: player,
          authorize?: true
        )
      end
    end

    test "rejects message with empty string body" do
      %{game: game, player_o: player} = active_game()

      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Message, %{body: "", game_id: game.id},
          action: :create,
          actor: player,
          authorize?: true
        )
      end
    end

    test "rejects message exceeding max length" do
      %{game: game, player_o: player} = active_game()
      long_body = String.duplicate("a", 501)

      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Message, %{body: long_body, game_id: game.id},
          action: :create,
          actor: player,
          authorize?: true
        )
      end
    end

    test "accepts message at exactly max length" do
      %{game: game, player_o: player} = active_game()
      body = String.duplicate("a", 500)

      message =
        Ash.create!(Message, %{body: body, game_id: game.id},
          action: :create,
          actor: player,
          authorize?: true
        )

      assert String.length(message.body) == 500
    end

    test "rejects message without an actor" do
      %{game: game} = active_game()

      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Message, %{body: "hello", game_id: game.id},
          action: :create,
          authorize?: true
        )
      end
    end

    test "rejects message without a game_id" do
      player = generate(user())

      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(Message, %{body: "hello"},
          action: :create,
          actor: player,
          authorize?: true
        )
      end
    end
  end

  describe "read actions" do
    test "anyone can read messages without an actor" do
      %{game: game, player_o: player} = active_game()

      Ash.create!(Message, %{body: "hi", game_id: game.id},
        action: :create,
        actor: player
      )

      messages = Ash.read!(Message, authorize?: true)
      assert length(messages) >= 1
    end

    test "by_game returns only messages for the given game" do
      %{game: game1, player_o: player1} = active_game()
      %{game: game2, player_o: player2} = active_game()

      Ash.create!(Message, %{body: "game 1 msg", game_id: game1.id},
        action: :create,
        actor: player1
      )

      Ash.create!(Message, %{body: "game 2 msg", game_id: game2.id},
        action: :create,
        actor: player2
      )

      messages = Games.list_messages!(game1.id)
      assert length(messages) == 1
      assert hd(messages).body == "game 1 msg"
    end

    test "by_game returns messages sorted by inserted_at ascending" do
      %{game: game, player_o: player} = active_game()

      Ash.create!(Message, %{body: "first", game_id: game.id},
        action: :create,
        actor: player
      )

      Ash.create!(Message, %{body: "second", game_id: game.id},
        action: :create,
        actor: player
      )

      Ash.create!(Message, %{body: "third", game_id: game.id},
        action: :create,
        actor: player
      )

      messages = Games.list_messages!(game.id)
      assert Enum.map(messages, & &1.body) == ["first", "second", "third"]
    end

    test "by_game returns empty list for game with no messages" do
      %{game: game} = active_game()

      messages = Games.list_messages!(game.id)
      assert messages == []
    end
  end

  describe "code interface" do
    test "create_message creates via domain interface" do
      %{game: game, player_o: player} = active_game()

      message = Games.create_message!("hello", %{game_id: game.id}, actor: player)

      assert message.body == "hello"
      assert message.game_id == game.id
      assert message.user_id == player.id
    end

    test "list_messages lists via domain interface" do
      %{game: game, player_o: player} = active_game()
      Games.create_message!("msg1", %{game_id: game.id}, actor: player)
      Games.create_message!("msg2", %{game_id: game.id}, actor: player)

      messages = Games.list_messages!(game.id)
      assert length(messages) == 2
    end
  end

  describe "relationships" do
    test "message belongs to a user that can be loaded" do
      %{game: game, player_o: player} = active_game()

      message =
        Games.create_message!("hi", %{game_id: game.id}, actor: player)
        |> Ash.load!(:user, authorize?: false)

      assert message.user.id == player.id
      assert message.user.name == player.name
    end

    test "message belongs to a game that can be loaded" do
      %{game: game, player_o: player} = active_game()

      message =
        Games.create_message!("hi", %{game_id: game.id}, actor: player)
        |> Ash.load!(:game, authorize?: false)

      assert message.game.id == game.id
    end

    test "game has_many messages that can be loaded" do
      %{game: game, player_o: player} = active_game()
      Games.create_message!("msg1", %{game_id: game.id}, actor: player)
      Games.create_message!("msg2", %{game_id: game.id}, actor: player)

      game = Ash.load!(game, :messages, authorize?: false)
      assert length(game.messages) == 2
    end
  end
end
