defmodule Xo.Games.Validations.ValidateGameState do
  @moduledoc """
  Validates that the game is in one of the expected states before allowing an action.
  Replaces AshStateMachine transition guards.
  """
  use Ash.Resource.Validation

  @states ~w(open active won draw)a

  @impl true
  def init(opts) do
    states = opts[:states]

    cond do
      not is_list(states) ->
        init(states: [states])

      Enum.all?(states, &(&1 in @states)) ->
        {:ok, opts}

      true ->
        {:error, "states must be in #{Enum.join(@states, ", ")}, got #{Enum.join(states, ", ")}"}
    end
  end

  @impl true
  def validate(changeset, opts, _context) do
    game = Ash.load!(changeset.data, :state)

    if game.state in opts[:states] do
      :ok
    else
      {:error,
       field: :state,
       message: "game must be in one of %{states}, got %{actual}",
       vars: %{states: inspect(opts[:states]), actual: inspect(game.state)}}
    end
  end
end
