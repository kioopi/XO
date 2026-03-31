defmodule XoWeb.PageController do
  use XoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
