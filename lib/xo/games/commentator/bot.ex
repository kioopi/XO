defmodule Xo.Games.Commentator.Bot do
  @moduledoc "Manages the AI commentator bot user."

  @bot_email "commentator@xo.bot"
  @bot_name "Commentator"

  require Ash.Query

  @doc "Returns the bot user, creating it if necessary."
  def user do
    Xo.Accounts.demo_create_user!(@bot_name, @bot_email)
  end
end
