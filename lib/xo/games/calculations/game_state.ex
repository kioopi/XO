defmodule Xo.Games.Calculations.GameState do
  @moduledoc """
  Derives the game state from the current data:
  - no player_x → :open
  - has winner → :won
  - 9 moves, no winner → :draw
  - otherwise → :active
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [:player_x_id, :winner_id, :move_count]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &game_state/1)
  end

  defp game_state(%{player_x_id: x}) when is_nil(x), do: :open
  defp game_state(%{winner_id: w}) when not is_nil(w), do: :won
  defp game_state(%{move_count: 9}), do: :draw
  defp game_state(_), do: :active

  @impl true
  def expression(_opts, _context) do
    expr(
      cond do
        is_nil(player_x_id) -> :open
        not is_nil(winner_id) -> :won
        move_count == 9 -> :draw
        true -> :active
      end
    )
  end
end
