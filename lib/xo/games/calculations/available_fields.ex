defmodule Xo.Games.Calculations.AvailableFields do
  @moduledoc """
  Returns the list of board positions (0-8) that have not been played yet.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [:player_o_fields, :player_x_fields]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn game ->
      occupied = MapSet.new((game.player_o_fields || []) ++ (game.player_x_fields || []))
      Enum.reject(0..8, &MapSet.member?(occupied, &1))
    end)
  end
end
