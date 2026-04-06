defmodule XoWeb.GameComponents do
  @moduledoc """
  Function components for the game page.
  """
  use Phoenix.Component
  use XoWeb, :verified_routes

  import XoWeb.CoreComponents

  attr :game, :any, required: true
  attr :role, :atom, required: true

  def game_header(assigns) do
    ~H"""
    <div class="flex items-center gap-3 mb-2">
      <h2 class="text-2xl font-bold tracking-tight">Game #{@game.id}</h2>
      <.game_state_badge state={@game.state} />
      <span class="text-sm text-base-content/50 font-medium">
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

  attr :status_text, :string, required: true
  attr :game_state, :atom, default: :active

  def game_status_banner(assigns) do
    ~H"""
    <div class={[
      "text-center py-4 px-6 rounded-2xl mb-6 bg-base-200/60",
      @game_state in [:won, :draw] && "animate-celebrate"
    ]}>
      <span class="text-2xl font-bold tracking-tight">{@status_text}</span>
    </div>
    """
  end

  attr :board, :list, required: true
  attr :clickable_fields, :list, required: true
  attr :disabled, :boolean, default: false
  attr :current_mark, :atom, default: nil
  attr :winning_cells, :list, default: []

  def board(assigns) do
    ~H"""
    <div class="bg-base-300 p-2.5 rounded-2xl shadow-lg max-w-sm mx-auto">
      <div class="grid grid-cols-3 gap-2 w-full aspect-square">
        <.board_cell
          :for={{value, index} <- Enum.with_index(@board)}
          value={value}
          index={index}
          clickable={not @disabled and index in @clickable_fields}
          current_mark={@current_mark}
          winning={index in @winning_cells}
        />
      </div>
    </div>
    """
  end

  attr :value, :atom, required: true
  attr :index, :integer, required: true
  attr :clickable, :boolean, required: true
  attr :current_mark, :atom, default: nil
  attr :winning, :boolean, default: false

  def board_cell(assigns) do
    ~H"""
    <button
      class={[
        "flex items-center justify-center aspect-square rounded-xl text-5xl md:text-6xl font-bold",
        "transition-all duration-200",
        cell_style(@value, @clickable),
        @clickable && "cell-clickable",
        @winning && "animate-win-glow"
      ]}
      disabled={not @clickable}
      phx-click={@clickable && "make_move"}
      phx-value-field={@clickable && @index}
    >
      <span :if={@value == :o} class="text-primary animate-mark-pop">O</span>
      <span :if={@value == :x} class="text-secondary animate-mark-pop">X</span>
      <%= if is_nil(@value) and @clickable do %>
        <span class={["ghost-mark", ghost_mark_color(@current_mark)]}>
          {ghost_mark_label(@current_mark)}
        </span>
      <% end %>
    </button>
    """
  end

  defp cell_style(nil, true),
    do: "bg-base-100 hover:bg-base-200 cursor-pointer hover:scale-[1.03]"

  defp cell_style(nil, false), do: "bg-base-100"
  defp cell_style(_mark, _), do: "bg-base-100"

  defp ghost_mark_color(:o), do: "text-primary"
  defp ghost_mark_color(:x), do: "text-secondary"
  defp ghost_mark_color(_), do: "text-base-content/30"

  defp ghost_mark_label(:o), do: "O"
  defp ghost_mark_label(:x), do: "X"
  defp ghost_mark_label(_), do: ""

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
        <div class="card bg-base-100 p-4 text-center text-base-content/40 rounded-xl border border-dashed border-base-300">
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
      "card bg-base-100 p-4 flex-row items-center gap-3 rounded-xl transition-all duration-300",
      @is_turn && !@is_winner && turn_pulse_class(@mark),
      @is_turn && !@is_winner && turn_ring_class(@mark),
      @is_winner && "ring-2 ring-success animate-win-glow",
      !@is_turn && !@is_winner && "border border-base-200"
    ]}>
      <span class={["text-3xl font-black", mark_color(@mark)]}>
        {mark_label(@mark)}
      </span>
      <span class="font-semibold flex-1">{@name}</span>
      <span :if={@is_you} class="badge badge-sm badge-ghost font-medium">You</span>
      <span
        :if={@is_turn && !@is_winner}
        class={["badge badge-sm font-medium", turn_badge_class(@mark)]}
      >
        Turn
      </span>
      <span :if={@is_winner} class="badge badge-sm badge-success font-medium">Winner</span>
    </div>
    """
  end

  defp mark_label(:o), do: "O"
  defp mark_label(:x), do: "X"

  defp mark_color(:o), do: "text-primary"
  defp mark_color(:x), do: "text-secondary"

  defp turn_ring_class(:o), do: "ring-2 ring-primary"
  defp turn_ring_class(:x), do: "ring-2 ring-secondary"

  defp turn_pulse_class(:o), do: "animate-turn-pulse"
  defp turn_pulse_class(:x), do: "animate-turn-pulse-x"

  defp turn_badge_class(:o), do: "badge-primary"
  defp turn_badge_class(:x), do: "badge-secondary"

  attr :game, :any, required: true
  attr :role, :atom, required: true
  attr :current_user, :any, default: nil

  def action_bar(assigns) do
    ~H"""
    <div class="flex gap-3 mt-4">
      <button
        :if={show_join_button?(@game, @current_user)}
        phx-click="join_game"
        class="btn btn-primary btn-lg rounded-xl flex-1"
      >
        Join Game
      </button>
      <.link navigate={~p"/"} class="btn btn-ghost rounded-xl">
        ← Back to Lobby
      </.link>
    </div>
    """
  end

  defp show_join_button?(_game, nil), do: false

  defp show_join_button?(game, user) do
    game.state == :open and user.id != game.player_o_id
  end

  attr :messages, :list, required: true
  attr :message_form, :any, required: true
  attr :current_user, :any, default: nil

  def chat_panel(assigns) do
    ~H"""
    <div class="card bg-base-100 rounded-xl border border-base-200 mt-4 flex flex-col max-h-80">
      <div class="px-4 py-3 border-b border-base-200">
        <h3 class="font-semibold text-sm">Chat</h3>
      </div>
      <div
        id="chat-messages"
        class="flex-1 overflow-y-auto px-4 py-2 space-y-2"
        phx-hook="ScrollBottom"
      >
        <p :if={@messages == []} class="text-sm text-base-content/40 text-center py-4">
          No messages yet
        </p>
        <div :for={msg <- @messages} class="text-sm">
          <span class="font-semibold">{msg.user.name}</span>
          <span class="text-base-content/70">{msg.body}</span>
        </div>
      </div>
      <div :if={@current_user} class="px-4 py-3 border-t border-base-200">
        <.form for={@message_form} phx-submit="send_message" phx-change="validate_message" class="flex gap-2">
          <.input
            field={@message_form[:body]}
            placeholder="Type a message..."
            class="input input-sm input-bordered flex-1 rounded-lg"
            autocomplete="off"
            maxlength="500"
          />
          <button type="submit" class="btn btn-sm btn-primary rounded-lg">Send</button>
        </.form>
      </div>
    </div>
    """
  end
end
