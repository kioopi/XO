defmodule XoWeb.GameUI do
  @moduledoc """
  Shared layout primitives for game pages.
  """
  use Phoenix.Component

  attr :title, :string, required: true
  slot :actions
  slot :inner_block

  def page_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-bold">{@title}</h1>
      <div :if={@actions != []} class="flex items-center gap-2">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <div class="mb-8">
      <h2 class="text-lg font-semibold mb-3">{@title}</h2>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :message, :string, required: true
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-8 text-base-content/60">
      <p>{@message}</p>
      <div :if={@actions != []} class="mt-4">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end
end
