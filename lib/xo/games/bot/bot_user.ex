defmodule Xo.Games.Bot.BotUser do
  @moduledoc "Manages bot user accounts, one per strategy. Cached in persistent_term."

  require Ash.Query

  def user(strategy_module) do
    email = strategy_module.bot_email()
    name = strategy_module.info().name

    case find_by_email(email) do
      nil ->
        user = Xo.Accounts.demo_create_user!(name, email)
        cache_put(strategy_module, user)
        user

      existing ->
        cache_put(strategy_module, existing)
        existing
    end
  end

  defp find_by_email(email) do
    Xo.Accounts.User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(authorize?: false)
  end

  defp cache_put(strategy_module, user) do
    :persistent_term.put({:bot_user, strategy_module}, user)
  end
end
