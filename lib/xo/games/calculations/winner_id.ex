defmodule Xo.Games.Calculations.WinnerId do
  @moduledoc """
  Calculates the winner of a game by checking each player's fields
  against winning combinations.
  """
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [:player_o_fields, :player_x_fields, :player_o_id, :player_x_id]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn game ->
      Xo.Games.WinChecker.find_winner(
        game.player_o_fields,
        game.player_x_fields,
        game.player_o_id,
        game.player_x_id
      )
    end)
  end

  @impl true
  def expression(_opts, _context) do
    won_expr = fn fields_agg ->
      Xo.Games.WinChecker.winning_combinations()
      |> Enum.reduce(nil, fn combo, acc ->
        check = expr(fragment("? @> ?::bigint[]", ^ref(fields_agg), ^combo))
        if acc, do: expr(^acc or ^check), else: check
      end)
    end

    player_o_won = won_expr.(:player_o_fields)
    player_x_won = won_expr.(:player_x_fields)

    expr(
      cond do
        ^player_o_won -> player_o_id
        ^player_x_won -> player_x_id
        true -> nil
      end
    )
  end
end
