defmodule XoWeb.GamePresenter do
  @moduledoc """
  Shapes domain Game data for UI display.

  Pure functions — no Phoenix dependencies, no database access.
  Receives already-loaded game structs and derives presentation values.
  """

  def role(_game, nil), do: :spectator

  def role(game, user) do
    cond do
      user.id == game.player_o_id -> :player_o
      user.id == game.player_x_id -> :player_x
      true -> :spectator
    end
  end

  def your_mark(game, user) do
    case role(game, user) do
      :player_o -> :o
      :player_x -> :x
      :spectator -> nil
    end
  end

  def clickable_fields(game, user) do
    if game.state == :active and user_id(user) == game.next_player_id do
      game.available_fields || []
    else
      []
    end
  end

  def status_text(game, user) do
    role = role(game, user)

    case game.state do
      :open -> "Waiting for an opponent to join"
      :draw -> "It's a draw!"
      :won -> won_text(game, user, role)
      :active -> turn_text(game, user, role)
    end
  end

  def winner_name(game) do
    cond do
      game.winner_id == nil -> nil
      game.winner_id == game.player_o.id -> game.player_o.name
      game.winner_id == game.player_x.id -> game.player_x.name
      true -> nil
    end
  end

  def player_display(game, which_player, current_user) do
    {player, mark, player_id} =
      case which_player do
        :player_o -> {game.player_o, :o, game.player_o_id}
        :player_x -> {game.player_x, :x, game.player_x_id}
      end

    %{
      name: player.name,
      mark: mark,
      is_turn: game.state == :active and game.next_player_id == player_id,
      is_winner: game.winner_id != nil and game.winner_id == player_id,
      is_you: current_user != nil and current_user.id == player_id
    }
  end

  defp user_id(nil), do: nil
  defp user_id(user), do: user.id

  defp won_text(game, user, role) do
    name = winner_name(game)

    cond do
      role != :spectator and game.winner_id == user.id -> "You won!"
      role == :spectator -> "#{name} won!"
      true -> "#{name} won"
    end
  end

  defp turn_text(game, _user, :spectator) do
    name = next_player_name(game)
    "#{name}'s turn"
  end

  defp turn_text(game, user, _role) do
    if game.next_player_id == user.id do
      "Your turn"
    else
      name = next_player_name(game)
      "#{name} is thinking..."
    end
  end

  def winning_cells(%{state: :won, board: board}) do
    o_fields = for {val, idx} <- Enum.with_index(board), val == :o, do: idx
    x_fields = for {val, idx} <- Enum.with_index(board), val == :x, do: idx

    Xo.Games.WinChecker.winning_combinations()
    |> Enum.find(fn combo ->
      Enum.all?(combo, &(&1 in o_fields)) or Enum.all?(combo, &(&1 in x_fields))
    end)
    |> Kernel.||([])
  end

  def winning_cells(_game), do: []

  defp next_player_name(game) do
    if game.next_player_id == game.player_o_id do
      game.player_o.name
    else
      game.player_x.name
    end
  end
end
