defmodule Xo.Games.Bot.Strategies.Strategic do
  @moduledoc "Bot strategy that prefers center/corners and blocks opponent wins."

  @behaviour Xo.Games.Bot.Behaviour

  @corners [0, 2, 6, 8]
  @edges [1, 3, 5, 7]

  @impl true
  def info do
    %{
      key: :strategic,
      name: "Strategic Bot",
      description: "Prefers center and corners. Blocks and takes winning moves."
    }
  end

  @impl true
  def bot_email, do: "strategic-bot@xo.bot"

  @impl true
  def select_move(game) do
    game = Ash.load!(game, [:available_fields, :player_o_fields, :player_x_fields])

    bot_fields = game.player_x_fields
    opponent_fields = game.player_o_fields
    available = game.available_fields

    field =
      find_winning_move(bot_fields, available) ||
        find_winning_move(opponent_fields, available) ||
        try_center(available) ||
        try_corners(available) ||
        try_edges(available)

    {:ok, field}
  end

  defp find_winning_move(player_fields, available) do
    Xo.Games.WinChecker.winning_combinations()
    |> Enum.find_value(fn combo ->
      in_combo = Enum.filter(combo, &(&1 in player_fields))
      open_in_combo = Enum.filter(combo, &(&1 in available))

      if length(in_combo) == 2 && length(open_in_combo) == 1 do
        hd(open_in_combo)
      end
    end)
  end

  defp try_center(available) do
    if 4 in available, do: 4
  end

  defp try_corners(available) do
    case Enum.filter(@corners, &(&1 in available)) do
      [] -> nil
      corners -> Enum.random(corners)
    end
  end

  defp try_edges(available) do
    case Enum.filter(@edges, &(&1 in available)) do
      [] -> nil
      edges -> Enum.random(edges)
    end
  end
end
