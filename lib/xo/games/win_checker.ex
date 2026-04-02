defmodule Xo.Games.WinChecker do
  @moduledoc """
  Shared winning logic for tic-tac-toe games.
  """

  @winning_combinations [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6]
  ]

  def winning_combinations, do: @winning_combinations

  def won?(fields) do
    Enum.any?(@winning_combinations, fn combo ->
      Enum.all?(combo, &(&1 in fields))
    end)
  end

  def find_winner(player_o_fields, player_x_fields, player_o_id, player_x_id) do
    cond do
      won?(player_o_fields) -> player_o_id
      won?(player_x_fields) -> player_x_id
      true -> nil
    end
  end
end
