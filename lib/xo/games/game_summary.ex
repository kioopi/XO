defmodule Xo.Games.GameSummary do
  @moduledoc """
  Formats game state as human-readable text.

  Pure functions — the caller is responsible for loading the required data.
  Used by both the AI commentator (for prompt context) and the Demo module (for REPL display).
  """

  alias Xo.Games.WinChecker

  @position_names %{
    0 => "top-left",
    1 => "top-center",
    2 => "top-right",
    3 => "middle-left",
    4 => "center",
    5 => "middle-right",
    6 => "bottom-left",
    7 => "bottom-center",
    8 => "bottom-right"
  }

  @doc """
  Returns a plain-text summary of the game suitable for AI commentary prompts.

  Expects a game loaded with: `:state`, `:board`, `:player_o`, `:player_x`,
  `:winner_id`, `:next_player_id`, `:move_count`, and `moves: [:player]`.
  """
  def for_prompt(game) do
    sections = [
      header(game),
      "\n",
      "Board (positions 0-8, left-to-right top-to-bottom):\n",
      board_text(game),
      "\n",
      position_key(),
      "\n",
      move_history(game)
    ]

    Enum.join(sections, "\n")
  end

  @doc """
  Returns a plain-text ASCII board with row/column labels.

  Expects a game with `:board` loaded.
  """
  def board_text(game) do
    cells =
      Enum.map(game.board, fn
        nil -> "_"
        :x -> "X"
        :o -> "O"
      end)

    rows = Enum.chunk_every(cells, 3)
    separator = "  +---+---+---+"

    body =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {[a, b, c], i} ->
        "#{i} | #{a} | #{b} | #{c} |"
      end)
      |> Enum.intersperse(separator)

    Enum.join(["    0   1   2", separator | body] ++ [separator], "\n")
  end

  @doc "Returns the human-readable name for a board position (0-8)."
  def position_name(index), do: Map.get(@position_names, index, "unknown")

  defp header(game) do
    lines = [
      "Game ##{game.id}",
      "Player O (mark: O): #{game.player_o.name}",
      "Player X (mark: X): #{if game.player_x, do: game.player_x.name, else: "waiting"}",
      "State: #{game.state}",
      "Move count: #{game.move_count}"
    ]

    lines =
      if game.state == :active && game.next_player_id do
        next = next_player_name(game)
        mark = next_player_mark(game)
        lines ++ ["Next turn: #{next} (#{mark})"]
      else
        lines
      end

    lines =
      if game.state == :won do
        lines ++ [winner_line(game)]
      else
        lines
      end

    Enum.join(lines, "\n")
  end

  defp next_player_name(game) do
    if game.next_player_id == game.player_o.id,
      do: game.player_o.name,
      else: game.player_x.name
  end

  defp next_player_mark(game) do
    if game.next_player_id == game.player_o.id, do: "O", else: "X"
  end

  defp winner_line(game) do
    {winner_name, winner_mark} =
      if game.winner_id == game.player_o.id,
        do: {game.player_o.name, "O"},
        else: {game.player_x.name, "X"}

    combo_label = winning_line_label(game.board)

    "Winner: #{winner_name} (#{winner_mark}) with #{combo_label}"
  end

  defp winning_line_label(board) do
    o_fields = fields_for_mark(board, :o)
    x_fields = fields_for_mark(board, :x)

    combo =
      WinChecker.winning_combinations()
      |> Enum.find(fn c ->
        Enum.all?(c, &(&1 in o_fields)) or Enum.all?(c, &(&1 in x_fields))
      end)

    case combo do
      nil -> "unknown"
      positions -> "positions #{inspect(positions)} (#{describe_combo(positions)})"
    end
  end

  defp fields_for_mark(board, mark) do
    board
    |> Enum.with_index()
    |> Enum.filter(fn {cell, _} -> cell == mark end)
    |> Enum.map(fn {_, i} -> i end)
  end

  defp describe_combo([0, 1, 2]), do: "top row"
  defp describe_combo([3, 4, 5]), do: "middle row"
  defp describe_combo([6, 7, 8]), do: "bottom row"
  defp describe_combo([0, 3, 6]), do: "left column"
  defp describe_combo([1, 4, 7]), do: "center column"
  defp describe_combo([2, 5, 8]), do: "right column"
  defp describe_combo([0, 4, 8]), do: "diagonal (top-left to bottom-right)"
  defp describe_combo([2, 4, 6]), do: "diagonal (top-right to bottom-left)"
  defp describe_combo(_), do: "line"

  defp position_key do
    @position_names
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {i, name} -> "#{i}=#{name}" end)
    |> Enum.join(", ")
    |> then(&"Position key: #{&1}")
  end

  defp move_history(game) do
    moves = game.moves |> Enum.sort_by(& &1.move_number)

    if Enum.empty?(moves) do
      "No moves yet."
    else
      lines =
        Enum.map(moves, fn m ->
          mark = if rem(m.move_number, 2) == 1, do: "O", else: "X"
          "#{m.move_number}. #{m.player.name} (#{mark}) → position #{m.field} (#{position_name(m.field)})"
        end)

      Enum.join(["Move history:" | lines], "\n")
    end
  end
end
