defmodule XoWeb.LobbyComponents do
  @moduledoc """
  Function components for the lobby page.
  """
  use Phoenix.Component
  use XoWeb, :verified_routes

  attr :state, :atom, required: true

  def game_state_badge(assigns) do
    ~H"""
    <span class={["badge badge-sm", badge_class(@state)]}>
      {@state}
    </span>
    """
  end

  defp badge_class(:open), do: "badge-info"
  defp badge_class(:active), do: "badge-warning"
  defp badge_class(:won), do: "badge-success"
  defp badge_class(:draw), do: "badge-neutral"
  defp badge_class(_), do: "badge-ghost"

  attr :games, :list, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true

  def games_list(assigns) do
    ~H"""
    <div class="grid gap-3">
      <.game_card :for={game <- @games} game={game} current_user={@current_user} variant={@variant} />
    </div>
    """
  end

  attr :game, :any, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true

  def game_card(assigns) do
    ~H"""
    <div class="card card-border bg-base-100 shadow-sm">
      <div class="card-body p-4 flex-row items-center justify-between">
        <div class="flex items-center gap-3">
          <.game_state_badge state={@game.state} />
          <div>
            <span class="font-medium">{creator_name(@game)}</span>
            <span :if={@variant == :active && @game.player_x} class="text-base-content/60">
              vs {@game.player_x.name}
            </span>
            <span :if={@game.move_count > 0} class="text-sm text-base-content/50 ml-2">
              · {@game.move_count} moves
            </span>
          </div>
        </div>
        <div>
          <.card_action game={@game} current_user={@current_user} variant={@variant} />
        </div>
      </div>
    </div>
    """
  end

  defp creator_name(game), do: game.player_o.name

  attr :game, :any, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true

  defp card_action(%{variant: :open, current_user: nil} = assigns) do
    ~H"""
    <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost">
      Watch
    </.link>
    """
  end

  defp card_action(%{variant: :open, current_user: user, game: game} = assigns) do
    if user.id == game.player_o_id do
      ~H"""
      <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost">
        Open
      </.link>
      """
    else
      ~H"""
      <button phx-click="join_game" phx-value-game-id={@game.id} class="btn btn-sm btn-primary">
        Join
      </button>
      """
    end
  end

  defp card_action(%{variant: :active} = assigns) do
    ~H"""
    <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost">
      Watch
    </.link>
    """
  end
end
