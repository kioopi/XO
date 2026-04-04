alias Xo.Games
alias Xo.Games.Game
alias Xo.Games.Move
alias Xo.Accounts
alias Xo.Demo, as: Demo

# import IEx.Helpers, only: [recompile: 1]

Application.put_env(:elixir, :ansi_enabled, true)

IEx.configure(
  colors: [
    eval_result: [:green, :bright],
    eval_info: [:yellow, :bright],
    eval_error: [:red, :bright]
  ],
  default_prompt: "x|o %prefix(%counter)> "
)

# Setup demo users — create if they don't exist, then sign in
case Accounts.demo_create_user("Xavier") do
  {:ok, user} -> user
  {:error, _} -> nil
end

case Accounts.demo_create_user("Olga") do
  {:ok, user} -> user
  {:error, _} -> nil
end

x = Accounts.demo_sign_in!("Xavier")
o = Accounts.demo_sign_in!("Olga")

# Welcome banner
IO.puts("""

#{IO.ANSI.bright()}#{IO.ANSI.cyan()}  ╔═══════════════════════════════════╗
  ║         #{IO.ANSI.red()}X#{IO.ANSI.cyan()}  Tic Tac Toe  #{IO.ANSI.blue()}O#{IO.ANSI.cyan()}         ║
  ╚═══════════════════════════════════╝#{IO.ANSI.reset()}

  #{IO.ANSI.faint()}Players ready:#{IO.ANSI.reset()}
    #{IO.ANSI.green()}x#{IO.ANSI.reset()} #{IO.ANSI.faint()}—#{IO.ANSI.reset()} #{x.name} (#{x.email})
    #{IO.ANSI.green()}o#{IO.ANSI.reset()} #{IO.ANSI.faint()}—#{IO.ANSI.reset()} #{o.name} (#{o.email})

  #{IO.ANSI.yellow()}Demo.help()#{IO.ANSI.reset()} #{IO.ANSI.faint()}—#{IO.ANSI.reset()} see usage examples
  #{IO.ANSI.yellow()}h Demo#{IO.ANSI.reset()}      #{IO.ANSI.faint()}—#{IO.ANSI.reset()} full module docs
""")
