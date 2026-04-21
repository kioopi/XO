defmodule Xo.Games.Calculations.WinnerId do
  @moduledoc """
  Resolves the winner's user id (or nil) by reusing the `:won` calculation
  twice — once against each player's fields.
  """
  use Ash.Resource.Calculation

  alias Xo.Games.Calculations.Won

  @impl true
  def load(_query, _opts, _context) do
    [
      :player_o_id,
      :player_x_id,
      won: %{fields: expr(player_o_fields), as: :player_o_won},
      won: %{fields: expr(player_x_fields), as: :player_x_won}
    ]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn
      %{player_x_won: true, player_x_id: id} -> id
      %{player_o_won: true, player_o_id: id} -> id
      _ -> nil
    end)
  end

  @impl true
  def expression(_opts, _context) do
    player_o_won = Won.win_expression(expr(player_o_fields))
    player_x_won = Won.win_expression(expr(player_x_fields))

    expr(
      cond do
        ^player_x_won -> player_x_id
        ^player_o_won -> player_o_id
        true -> nil
      end
    )
  end
end
