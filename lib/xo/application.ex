defmodule Xo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      XoWeb.Telemetry,
      Xo.Repo,
      {DNSCluster, query: Application.get_env(:xo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Xo.PubSub},
      {Registry, keys: :unique, name: Xo.Games.CommentatorRegistry},
      {Task.Supervisor, name: Xo.Games.CommentatorTaskSupervisor},
      {DynamicSupervisor, name: Xo.Games.CommentatorSupervisor, strategy: :one_for_one},
      {Registry, keys: :unique, name: Xo.Games.BotRegistry},
      {DynamicSupervisor, name: Xo.Games.BotSupervisor, strategy: :one_for_one},
      # Start to serve requests, typically the last entry
      XoWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :xo]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Xo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    XoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
