defmodule Xo.Games.Bot.BotUser do
  @moduledoc "Manages bot user accounts, one per strategy"

  require Ash.Query

  def user(strategy_module) do
    email = strategy_module.bot_email()
    name = strategy_module.info().name

    Xo.Accounts.demo_create_user!(name, email)
  end
end
