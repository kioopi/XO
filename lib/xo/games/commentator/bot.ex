defmodule Xo.Games.Commentator.Bot do
  @moduledoc "Manages the AI commentator bot user."

  @bot_email "commentator@xo.bot"
  @bot_name "Commentator"
  @persistent_term_key :commentator_bot_user

  require Ash.Query

  @doc "Returns the bot user, creating it if necessary."
  def user do
    case :persistent_term.get(@persistent_term_key, nil) do
      nil -> ensure_user()
      user -> user
    end
  end

  defp ensure_user do
    user =
      case Xo.Accounts.User
           |> Ash.Query.filter(email == ^@bot_email)
           |> Ash.read_one!(authorize?: false) do
        nil ->
          Xo.Accounts.demo_create_user!(@bot_name, @bot_email)

        existing ->
          existing
      end

    :persistent_term.put(@persistent_term_key, user)
    user
  end
end
