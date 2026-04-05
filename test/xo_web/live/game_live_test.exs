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
end
