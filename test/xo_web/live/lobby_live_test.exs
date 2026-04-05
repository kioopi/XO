defmodule XoWeb.LobbyLiveTest do
  use XoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Xo.Generators.User, only: [user: 0]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games

  describe "unauthenticated user" do
    test "can view the lobby", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "XO"
    end

    test "sees open games", %{conn: conn} do
      player = generate(user())
      Games.create_game!(actor: player)

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ player.name
    end

    test "does not see create game button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      refute html =~ "New Game"
    end
  end

  describe "authenticated user" do
    setup %{conn: conn} do
      user = generate(user())
      %{conn: log_in(conn, user), user: user}
    end

    test "sees create game button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "New Game"
    end

    test "can create a game", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("button", "New Game")
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"/games/\d+"
    end

    test "can join an open game", %{conn: conn, user: _user} do
      creator = generate(user())
      game = Games.create_game!(actor: creator)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("button[phx-value-game-id='#{game.id}']", "Join")
      |> render_click()

      assert_redirect(view, "/games/#{game.id}")
    end
  end

  defp log_in(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)
    user_with_token = Ash.Resource.put_metadata(user, :token, token)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Phoenix.Plug.store_in_session(user_with_token)
  end
end
