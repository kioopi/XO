defmodule Xo.Games.Commentator.GenerateCommentary do
  @moduledoc """
  Dispatches commentary generation to either the tools-based or context-based action
  depending on the `:commentator_use_tools` application config.
  """

  use Ash.Resource.Actions.Implementation

  alias Xo.Games.GameSummary

  @impl true
  def run(input, _opts, context) do
    input.resource
    |> generate_commentary_action_input(
      Application.get_env(:xo, :commentator_use_tools, false),
      %{
        game_id: input.arguments.game_id,
        event_description: input.arguments.event_description
      },
      actor: context.actor
    )
    |> Ash.run_action()
  end

  defp generate_commentary_action_input(resource, true, params, opts) do
    resource
    |> Ash.ActionInput.for_action(
      :generate_commentary_with_tools,
      params,
      opts
    )
  end

  defp generate_commentary_action_input(
         resource,
         # use tools
         false,
         %{game_id: id, event_description: description},
         opts
       ) do
    resource
    |> Ash.ActionInput.for_action(
      :generate_commentary_with_context,
      %{
        game_context: GameSummary.for_prompt(load_game!(id)),
        event_description: description
      },
      opts
    )
  end

  defp load_game!(game_id) do
    Xo.Games.get_by_id!(game_id,
      load: [
        :state,
        :board,
        :player_o,
        :player_x,
        :winner_id,
        :next_player_id,
        :move_count,
        moves: [:player]
      ],
      authorize?: false
    )
  end
end
