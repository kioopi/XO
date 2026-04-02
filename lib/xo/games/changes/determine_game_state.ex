defmodule Xo.Games.Changes.DetermineGameState do
  @moduledoc """
  Change for Game.make_move that determines the game state after a move.

  Loads existing board positions via aggregates, simulates the new move,
  and transitions state to :won, :draw, or :active accordingly.
  """
  use Ash.Resource.Change

  alias Ash.Changeset

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

  @required_game_data [
    :player_o_fields,
    :player_x_fields,
    :move_count,
    :next_player_id
  ]

  @impl true
  def change(changeset, _opts, _context) do
    field = Changeset.get_argument(changeset, :field)
    game = load_game(changeset)

    changeset
    |> transition_state(game, current_player_fields(game, field))
  end

  defp load_game(changeset) do
    Ash.load!(changeset.data, @required_game_data)
  end

  # Add the current move to the already played moves of the current player
  defp current_player_fields(game, field)  do
    [field | player_fields(game)]
  end

  defp player_fields(%{ next_player_id: player, player_o_id: o } = game) when
  player ==
  o, do: game.player_o_fields
  defp player_fields(game), do: game.player_x_fields


  defp transition_state(changeset, game, current_player_fields) do
    if won?(current_player_fields) do
      changeset
      |> AshStateMachine.transition_state(:won)
      |> Changeset.force_change_attribute(:winner_id, game.next_player_id)
    else
      AshStateMachine.transition_state(changeset, new_state(game.move_count))
    end
  end

  defp new_state(8), do: :draw
  defp new_state(_move_count), do: :active

  defp won?(fields) do
    Enum.any?(@winning_combinations, fn combo ->
      Enum.all?(combo, &(&1 in fields))
    end)
  end
end
