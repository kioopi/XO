defmodule Xo.Games.Calculations.Board do
  @moduledoc """
  Builds a 9-element list representing the current board.

  Each position is `:o` (player O), `:x` (player X), or `nil` (empty).
  """
  use Ash.Resource.Calculation

  require Ash.Expr

  @impl true
  def load(_query, _opts, _context) do
    [:player_o_fields, :player_x_fields]
  end

  @impl true
  def expression(_opts, _context) do
    Ash.Expr.expr(
      fragment(
        "ARRAY(SELECT CASE WHEN i = ANY(?) THEN 'o' WHEN i = ANY(?) THEN 'x' ELSE NULL END FROM generate_series(0, 8) AS i)",
        player_o_fields,
        player_x_fields
      )
    )
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn game ->
      o_fields = MapSet.new(game.player_o_fields || [])
      x_fields = MapSet.new(game.player_x_fields || [])

      Enum.map(0..8, fn i ->
        cond do
          MapSet.member?(o_fields, i) -> :o
          MapSet.member?(x_fields, i) -> :x
          true -> nil
        end
      end)
    end)
  end
end
