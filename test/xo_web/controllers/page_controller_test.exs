defmodule XoWeb.PageControllerTest do
  use XoWeb.ConnCase, async: true

  test "GET / renders the lobby", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "XO"
  end
end
