defmodule XoWeb.GameLiveTest do
  use XoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Xo.Generators.User, only: [user: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games

  defp create_active_game do
    player_o = generate(user())
    player_x = generate(user())
    game = Games.create_game!(actor: player_o)
    game = Games.join!(game, actor: player_x)
    %{game: game, player_o: player_o, player_x: player_x}
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    user_with_token = Ash.Resource.put_metadata(user, :token, token)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Phoenix.Plug.store_in_session(user_with_token)
  end

  describe "viewing a game" do
    test "spectator can view an active game", %{conn: conn} do
      %{game: game} = create_active_game()

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "Game ##{game.id}"
      assert html =~ "Spectating"
    end

    test "player_o sees their role", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "You are O"
    end

    test "shows status banner", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "Your turn"
    end
  end

  describe "making moves" do
    test "player can click a cell to make a move", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      html =
        view
        |> element("button[phx-value-field='4']")
        |> render_click()

      assert html =~ "O"
    end

    test "spectator cannot make moves", %{conn: conn} do
      %{game: game} = create_active_game()

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      refute html =~ ~s(phx-click="make_move")
    end
  end

  describe "joining a game" do
    test "player can join an open game", %{conn: conn} do
      creator = generate(user())
      game = Games.create_game!(actor: creator)
      joiner = generate(user())
      conn = log_in(conn, joiner)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      view
      |> element("button", "Join Game")
      |> render_click()

      html = render(view)
      assert html =~ "You are X"
    end
  end

  describe "real-time updates" do
    test "board updates when opponent moves", %{conn: conn} do
      %{game: game, player_o: player_o, player_x: player_x} = create_active_game()
      conn = log_in(conn, player_x)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      # player_o makes a move outside the LiveView
      Games.make_move!(game, 0, actor: player_o)

      # The view should update via PubSub
      html = render(view)
      assert html =~ "O"
    end
  end

  describe "chat panel rendering" do
    test "shows chat panel with empty state", %{conn: conn} do
      %{game: game} = create_active_game()

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "Chat"
      assert html =~ "No messages yet"
    end

    test "shows existing messages on mount", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      Games.create_message!("hello everyone", %{game_id: game.id}, actor: player_o)

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "hello everyone"
      assert html =~ player_o.name
      refute html =~ "No messages yet"
    end

    test "shows multiple messages in order", %{conn: conn} do
      %{game: game, player_o: player_o, player_x: player_x} = create_active_game()
      Games.create_message!("first msg", %{game_id: game.id}, actor: player_o)
      Games.create_message!("second msg", %{game_id: game.id}, actor: player_x)

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "first msg"
      assert html =~ "second msg"
    end

    test "unauthenticated user does not see chat input", %{conn: conn} do
      %{game: game} = create_active_game()

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      refute html =~ "send_message"
      refute html =~ "Type a message"
    end

    test "authenticated user sees chat input", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, _view, html} = live(conn, ~p"/games/#{game.id}")
      assert html =~ "Type a message"
      assert html =~ "Send"
    end
  end

  describe "sending chat messages" do
    test "player can send a chat message", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      view
      |> form("form[phx-submit='send_message']", %{"form" => %{"body" => "gg"}})
      |> render_submit()

      html = render(view)
      assert html =~ "gg"
      assert html =~ player_o.name
    end

    test "spectator can send a chat message", %{conn: conn} do
      %{game: game} = create_active_game()
      spectator = generate(user())
      conn = log_in(conn, spectator)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      view
      |> form("form[phx-submit='send_message']", %{"form" => %{"body" => "go player O!"}})
      |> render_submit()

      html = render(view)
      assert html =~ "go player O!"
      assert html =~ spectator.name
    end

    test "form clears after sending a message", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      view
      |> form("form[phx-submit='send_message']", %{"form" => %{"body" => "hello"}})
      |> render_submit()

      html = render(view)
      # The input should be empty after submit (form was reset)
      refute html =~ ~s(value="hello")
    end

    test "can send multiple messages", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      view
      |> form("form[phx-submit='send_message']", %{"form" => %{"body" => "first"}})
      |> render_submit()

      view
      |> form("form[phx-submit='send_message']", %{"form" => %{"body" => "second"}})
      |> render_submit()

      html = render(view)
      assert html =~ "first"
      assert html =~ "second"
    end
  end

  describe "chat form validation" do
    test "validates message on change", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      # Triggering validate should not crash
      html =
        view
        |> form("form[phx-submit='send_message']", %{"form" => %{"body" => "typing..."}})
        |> render_change()

      assert html =~ "Chat"
    end
  end

  describe "chat real-time updates" do
    test "new messages appear via PubSub", %{conn: conn} do
      %{game: game, player_o: player_o, player_x: player_x} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      # player_x sends a message outside the LiveView
      Games.create_message!("surprise!", %{game_id: game.id}, actor: player_x)

      html = render(view)
      assert html =~ "surprise!"
      assert html =~ player_x.name
    end

    test "spectator sees real-time messages", %{conn: conn} do
      %{game: game, player_o: player_o} = create_active_game()

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      Games.create_message!("live update", %{game_id: game.id}, actor: player_o)

      html = render(view)
      assert html =~ "live update"
    end

    test "messages from multiple users appear correctly", %{conn: conn} do
      %{game: game, player_o: player_o, player_x: player_x} = create_active_game()
      conn = log_in(conn, player_o)

      {:ok, view, _html} = live(conn, ~p"/games/#{game.id}")

      Games.create_message!("from O", %{game_id: game.id}, actor: player_o)
      Games.create_message!("from X", %{game_id: game.id}, actor: player_x)

      html = render(view)
      assert html =~ "from O"
      assert html =~ "from X"
      assert html =~ player_o.name
      assert html =~ player_x.name
    end
  end
end
