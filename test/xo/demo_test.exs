defmodule Xo.DemoTest do
  use Xo.DataCase, async: true

  import ExUnit.CaptureIO
  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Demo

  describe "board/1" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "renders empty board with field numbers", %{game: game} do
      output = capture_io(fn -> assert Demo.board(game) == :ok end)

      for i <- 0..8 do
        assert output =~ "#{i}"
      end
    end

    test "renders X and O for played fields", %{
      game: game,
      player_o: player_o,
      player_x: player_x
    } do
      game =
        Ash.update!(game, %{field: 0}, action: :make_move, actor: player_o, authorize?: true)

      game =
        Ash.update!(game, %{field: 4}, action: :make_move, actor: player_x, authorize?: true)

      output = capture_io(fn -> assert Demo.board(game) == :ok end)

      assert output =~ "O"
      assert output =~ "X"
    end
  end
end
