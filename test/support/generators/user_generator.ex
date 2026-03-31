defmodule Xo.Generators.User do
  use Ash.Generator

  alias Xo.Accounts.User

  def user(overrides \\ %{}) do
    seed_generator(
      {User,
       %{
         email: sequence(:user_email, &"user#{&1}@example.com")
       }},
      overrides: overrides
    )
  end
end
