defmodule Xo.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Xo.Accounts.User, _opts, _context) do
    Application.fetch_env(:xo, :token_signing_secret)
  end
end
