defmodule Xo.Games.Calculations.Won do
  @moduledoc """
  Whether a given set of fields contains a winning combination.
  """
  use Ash.Resource.Calculation

  @impl true
  def calculate(records, _opts, %{arguments: args}) do
    Enum.map(records, fn _game ->
      Xo.Games.WinChecker.won?(args.fields)
    end)
  end

  @impl true
  def expression(_opts, _context) do
    win_expression(expr(^arg(:fields)))
  end

  @doc """
  Builds a DB-pushable boolean expression that is true when `fields_expr`
  (an Ash expression resolving to an array of field indexes) contains any
  winning combination. Exposed so other calculations can reuse this logic
  without going through calculation arguments.
  """
  def win_expression(fields_expr) do
    Xo.Games.WinChecker.winning_combinations()
    |> Enum.reduce(nil, fn combo, acc ->
      check = expr(fragment("? @> ?::bigint[]", ^fields_expr, ^combo))
      if acc, do: expr(^acc or ^check), else: check
    end)
  end
end
