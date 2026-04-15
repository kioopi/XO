defmodule Xo.Games.Commentator.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: Xo.Games.CommentatorRegistry},
      {Task.Supervisor, name: Xo.Games.CommentatorTaskSupervisor},
      {DynamicSupervisor, name: Xo.Games.CommentatorSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
