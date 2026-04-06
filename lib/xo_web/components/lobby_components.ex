defmodule XoWeb.LobbyComponents do
  @moduledoc """
  Function components for the lobby page.
  """
  use Phoenix.Component
  use XoWeb, :verified_routes

  attr :current_user, :any, default: nil

  def player_status(%{current_user: nil} = assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-md rounded-xl mb-8">
      <div class="card-body p-5">
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
          <span class="text-base-content/50 font-medium">Not signed in</span>
          <div class="flex flex-wrap items-center gap-2">
            <.link navigate={~p"/sign-in"} class="btn btn-sm btn-outline rounded-lg">
              Sign in with magic link
            </.link>
            <.link href="/demo-sign-in/x" class="btn btn-sm btn-secondary rounded-lg">
              Play as Xavier (X)
            </.link>
            <.link href="/demo-sign-in/o" class="btn btn-sm btn-primary rounded-lg">
              Play as Olga (O)
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def player_status(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-md rounded-xl mb-8">
      <div class="card-body p-5">
        <div class="flex items-center justify-between">
          <span class="font-medium">
            Signed in as <span class="font-bold">{@current_user.name}</span>
          </span>
          <.link href={~p"/sign-out"} class="btn btn-sm btn-ghost rounded-lg">
            Sign out
          </.link>
        </div>
      </div>
    </div>
    """
  end

  attr :state, :atom, required: true

  def game_state_badge(assigns) do
    ~H"""
    <span class={["badge badge-sm font-semibold", badge_class(@state)]}>
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
    <div class="grid gap-4">
      <.game_card :for={game <- @games} game={game} current_user={@current_user} variant={@variant} />
    </div>
    """
  end

  attr :game, :any, required: true
  attr :current_user, :any, default: nil
  attr :variant, :atom, required: true

  def game_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 rounded-xl">
      <div class="card-body p-4 flex-row items-center justify-between">
        <div class="flex items-center gap-3">
          <.game_state_badge state={@game.state} />
          <div>
            <span class="font-semibold">{creator_name(@game)}</span>
            <span :if={@variant == :active && @game.player_x} class="text-base-content/50">
              vs {@game.player_x.name}
            </span>
            <span :if={@game.move_count > 0} class="text-sm text-base-content/40 ml-2">
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
    <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost rounded-lg">
      Watch
    </.link>
    """
  end

  defp card_action(%{variant: :open, current_user: user, game: game} = assigns) do
    if user.id == game.player_o_id do
      ~H"""
      <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost rounded-lg">
        Open
      </.link>
      """
    else
      ~H"""
      <button
        phx-click="join_game"
        phx-value-game-id={@game.id}
        class="btn btn-sm btn-primary rounded-lg"
      >
        Join
      </button>
      """
    end
  end

  defp card_action(%{variant: :active} = assigns) do
    ~H"""
    <.link navigate={~p"/games/#{@game.id}"} class="btn btn-sm btn-ghost rounded-lg">
      Watch
    </.link>
    """
  end
end
