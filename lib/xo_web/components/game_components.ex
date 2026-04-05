defmodule XoWeb.GameComponents do
  @moduledoc """
  Function components for the game page.
  """
  use Phoenix.Component
  use XoWeb, :verified_routes

  attr :game, :any, required: true
  attr :role, :atom, required: true

  def game_header(assigns) do
    ~H"""
    <div class="flex items-center gap-3 mb-2">
      <h2 class="text-xl font-bold">Game #{@game.id}</h2>
      <.game_state_badge state={@game.state} />
      <span class="text-sm text-base-content/60">
        {role_label(@role)}
      </span>
    </div>
    """
  end

  defp role_label(:player_o), do: "You are O"
  defp role_label(:player_x), do: "You are X"
  defp role_label(:spectator), do: "Spectating"

  attr :state, :atom, required: true

  defp game_state_badge(assigns) do
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

  attr :status_text, :string, required: true

  def game_status_banner(assigns) do
    ~H"""
    <div class="alert mb-4">
      <span class="text-lg font-medium">{@status_text}</span>
    </div>
    """
  end

  attr :board, :list, required: true
  attr :clickable_fields, :list, required: true
  attr :disabled, :boolean, default: false

  def board(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-1 w-full max-w-xs mx-auto aspect-square">
      <.board_cell
        :for={{value, index} <- Enum.with_index(@board)}
        value={value}
        index={index}
        clickable={not @disabled and index in @clickable_fields}
      />
    </div>
    """
  end

  attr :value, :atom, required: true
  attr :index, :integer, required: true
  attr :clickable, :boolean, required: true

  def board_cell(assigns) do
    ~H"""
    <button
      class={[
        "flex items-center justify-center aspect-square rounded-lg text-3xl font-bold",
        "min-h-16 min-w-16",
        cell_style(@value, @clickable)
      ]}
      disabled={not @clickable}
      phx-click={@clickable && "make_move"}
      phx-value-field={@clickable && @index}
    >
      <span :if={@value == :o} class="text-primary">O</span>
      <span :if={@value == :x} class="text-secondary">X</span>
      <span :if={is_nil(@value) and @clickable} class="text-base-content/20">·</span>
    </button>
    """
  end

  defp cell_style(nil, true), do: "bg-base-200 hover:bg-base-300 cursor-pointer"
  defp cell_style(nil, false), do: "bg-base-200"
  defp cell_style(_mark, _), do: "bg-base-200"

  attr :game, :any, required: true
  attr :role, :atom, required: true
  attr :current_user, :any, default: nil

  def players_panel(assigns) do
    assigns =
      assigns
      |> assign(
        :player_o_display,
        XoWeb.GamePresenter.player_display(assigns.game, :player_o, assigns.current_user)
      )
      |> assign(
        :player_x_display,
        if(assigns.game.player_x,
          do: XoWeb.GamePresenter.player_display(assigns.game, :player_x, assigns.current_user)
        )
      )

    ~H"""
    <div class="flex flex-col gap-3">
      <.player_card {@player_o_display} />
      <%= if @player_x_display do %>
        <.player_card {@player_x_display} />
      <% else %>
        <div class="card card-border bg-base-100 p-4 text-center text-base-content/50">
          Waiting for opponent...
        </div>
      <% end %>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :mark, :atom, required: true
  attr :is_turn, :boolean, required: true
  attr :is_winner, :boolean, required: true
  attr :is_you, :boolean, required: true

  def player_card(assigns) do
    ~H"""
    <div class={[
      "card card-border bg-base-100 p-4 flex-row items-center gap-3",
      @is_turn && "ring-2 ring-primary",
      @is_winner && "ring-2 ring-success"
    ]}>
      <span class={["text-xl font-bold", mark_color(@mark)]}>
        {mark_label(@mark)}
      </span>
      <span class="font-medium">{@name}</span>
      <span :if={@is_you} class="badge badge-sm badge-ghost">You</span>
      <span :if={@is_turn} class="badge badge-sm badge-primary">Turn</span>
      <span :if={@is_winner} class="badge badge-sm badge-success">Winner</span>
    </div>
    """
  end

  defp mark_label(:o), do: "O"
  defp mark_label(:x), do: "X"

  defp mark_color(:o), do: "text-primary"
  defp mark_color(:x), do: "text-secondary"

  attr :game, :any, required: true
  attr :role, :atom, required: true
  attr :current_user, :any, default: nil

  def action_bar(assigns) do
    ~H"""
    <div class="flex gap-2 mt-4">
      <button
        :if={show_join_button?(@game, @current_user)}
        phx-click="join_game"
        class="btn btn-primary"
      >
        Join Game
      </button>
      <.link navigate={~p"/"} class="btn btn-ghost">
        ← Back to Lobby
      </.link>
    </div>
    """
  end

  defp show_join_button?(_game, nil), do: false

  defp show_join_button?(game, user) do
    game.state == :open and user.id != game.player_o_id
  end
end
