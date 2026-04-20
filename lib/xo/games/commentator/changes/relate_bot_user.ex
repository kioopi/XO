defmodule Xo.Games.Commentator.Changes.RelateBotUser do
  @moduledoc """
  Pins the message's `:user` relationship to the commentator bot, regardless of
  which actor invoked the action. Messages created through `:post_commentary`
  are always authored by the bot.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    bot = Xo.Games.Commentator.Bot.user()

    Ash.Changeset.manage_relationship(changeset, :user, bot, type: :append)
  end
end
