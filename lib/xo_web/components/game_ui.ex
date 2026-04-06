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
    <div class="flex items-center justify-between mb-8">
      <h1 class="text-3xl font-bold tracking-tight">{@title}</h1>
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
    <div class="mb-10">
      <h2 class="text-xl font-semibold tracking-tight text-base-content/80 mb-4 border-l-4 border-primary pl-3">
        {@title}
      </h2>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :message, :string, required: true
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-12 text-base-content/50">
      <p class="text-lg">{@message}</p>
      <div :if={@actions != []} class="mt-4">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end
end
