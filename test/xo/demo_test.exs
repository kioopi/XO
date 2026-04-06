defmodule Xo.DemoTest do
  use Xo.DataCase, async: true

  import ExUnit.CaptureIO
  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Demo

  describe "show/1" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "displays game state and board", %{game: game} do
      output = capture_io(fn -> assert Demo.show(game) == :ok end)

      assert output =~ "active"
      assert output =~ "Board"
    end

    test "displays player names", %{game: game, player_o: player_o, player_x: player_x} do
      output = capture_io(fn -> assert Demo.show(game) == :ok end)

      assert output =~ player_o.name
      assert output =~ player_x.name
    end

    test "displays available fields", %{game: game, player_o: player_o} do
      game =
        Ash.update!(game, %{field: 4}, action: :make_move, actor: player_o, authorize?: true)

      output = capture_io(fn -> assert Demo.show(game) == :ok end)

      assert output =~ "Available"
      refute output =~ ~r/\b4\b.*Available/s
    end

    test "displays winner on won game", %{game: game, player_o: player_o, player_x: player_x} do
      game =
        [0, 3, 1, 4, 2]
        |> Enum.reduce({game, 0}, fn field, {game, index} ->
          actor = if rem(index, 2) == 0, do: player_o, else: player_x

          game =
            Ash.update!(game, %{field: field}, action: :make_move, actor: actor, authorize?: true)

          {game, index + 1}
        end)
        |> elem(0)

      output = capture_io(fn -> assert Demo.show(game) == :ok end)

      assert output =~ "won"
      assert output =~ player_o.name
    end
  end

  describe "board/1" do
    setup do
      player_o = generate(user())
      game = generate(game(actor: player_o))
      player_x = generate(user())
      active_game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

      %{game: active_game, player_o: player_o, player_x: player_x}
    end

    test "renders empty board with labeled axes and underscores", %{game: game} do
      output = capture_io(fn -> assert Demo.board(game) == :ok end)

      # Column headers and row labels
      for i <- 0..2 do
        assert output =~ "#{i}"
      end

      # Empty cells shown as underscores
      assert output =~ "_"
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
