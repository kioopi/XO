defmodule Xo.Games.Bot.Strategy do
  @moduledoc "Ash resource representing available bot strategies."

  use Ash.Resource,
    otp_app: :xo,
    domain: Xo.Games,
    data_layer: Ash.DataLayer.Simple

  @modules %{
    random: Xo.Games.Bot.Strategies.Random,
    strategic: Xo.Games.Bot.Strategies.Strategic
  }

  def all_modules, do: Map.values(@modules)

  def module_for!(key), do: Map.fetch!(@modules, key)

  attributes do
    attribute :key, :atom, primary_key?: true, allow_nil?: false, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
  end

  actions do
    read :read do
      manual fn _, _, _ ->
        strategies =
          for module <- all_modules() do
            info = module.info()
            struct!(__MODULE__, info)
          end

        {:ok, strategies}
      end
    end
  end
end
