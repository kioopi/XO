defmodule Xo.Games.Message do
  use Ash.Resource,
    otp_app: :xo,
    domain: Xo.Games,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    fragments: [Xo.Games.Commentator.MessageFragment]

  alias Xo.Accounts.User
  alias Xo.Games.Game

  postgres do
    table "messages"
    repo Xo.Repo
  end

  actions do
    defaults [:read]

    read :by_game do
      description "List chat messages for a given game, oldest first."

      argument :game_id, :integer do
        allow_nil? false
      end

      prepare build(sort: [inserted_at: :asc])
      filter expr(game_id == ^arg(:game_id))
    end

    create :create do
      description "Send a chat message in a game."
      accept [:body, :game_id]
      change relate_actor(:user, allow_nil?: false)
    end
  end

  policies do
    policy action_type(:read) do
      description "Anyone can read chat messages."
      authorize_if always()
    end

    policy action_type(:create) do
      description "Authenticated users can send chat messages."
      authorize_if actor_present()
    end
  end

  pub_sub do
    module XoWeb.Endpoint
    prefix "game"

    publish_all :create, ["chat", :game_id], load: [:user]
  end

  attributes do
    integer_primary_key :id

    attribute :body, :string do
      description "The message text."
      allow_nil? false
      public? true
      constraints max_length: 500
    end

    timestamps()
  end

  relationships do
    belongs_to :user, User do
      description "The user who sent this message."
      public? true
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :game, Game do
      description "The game this message belongs to."
      public? true
      allow_nil? false
      attribute_type :integer
    end
  end
end
