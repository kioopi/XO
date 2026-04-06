defmodule Xo.Demo do
  @moduledoc """
  Demo helpers for exploring Xo in the IEx REPL.

  ## Quick Start

  When you open `iex -S mix`, two users are automatically created and signed in:

    * `x` — Xavier (xavier@example.com)
    * `o` — Olga (olga@example.com)

  ## Available Functions

    * `Demo.help/0`  — Print an overview of all demo helpers
    * `Demo.games/0` — Print examples for creating, joining, and listing games
    * `Demo.moves/0` — Print examples for making moves and playing a full game
    * `Demo.users/0` — Print info about the current demo users (x and o)

  ## Example Session

      game = Games.create_game!(actor: x)
      Games.join!(game, actor: o)
      game = Games.make_move!(game, 0, actor: x)
      game = Games.make_move!(game, 4, actor: o)

  """

  @green IO.ANSI.green()
  @cyan IO.ANSI.cyan()
  @yellow IO.ANSI.yellow()
  @white IO.ANSI.white()
  @bright IO.ANSI.bright()
  @reset IO.ANSI.reset()
  @dim IO.ANSI.faint()

  @doc """
  Print an overview of all demo helpers.
  """
  def help do
    IO.puts("""

    #{@bright}#{@cyan}Xo Demo Helpers#{@reset}

      #{@yellow}Demo.help/0#{@reset}   #{@dim}—#{@reset} This overview
      #{@yellow}Demo.users/0#{@reset}  #{@dim}—#{@reset} Show demo users (x and o)
      #{@yellow}Demo.games/0#{@reset}  #{@dim}—#{@reset} Game creation & joining examples
      #{@yellow}Demo.moves/0#{@reset}  #{@dim}—#{@reset} Making moves & gameplay examples

      #{@dim}Tip: use#{@reset} #{@green}h Demo#{@reset} #{@dim}for full module docs#{@reset}
    """)

    :ok
  end

  @doc """
  Print info about the current demo users.
  """
  def users do
    IO.puts("""

    #{@bright}#{@cyan}Demo Users#{@reset}

      #{@green}x#{@reset} #{@dim}—#{@reset} Xavier (xavier@example.com)
      #{@green}o#{@reset} #{@dim}—#{@reset} Olga (olga@example.com)

      #{@dim}Both are signed in and ready to use as#{@reset} #{@yellow}actor:#{@reset}

      #{@white}Games.create_game!(actor: x)#{@reset}
      #{@white}Games.join!(game, actor: o)#{@reset}
    """)

    :ok
  end

  @doc """
  Print examples for creating, joining, and listing games.
  """
  def games do
    IO.puts("""

    #{@bright}#{@cyan}Games#{@reset}

      #{@dim}# Create a new game#{@reset}
      #{@white}game = Games.create_game!(actor: x)#{@reset}

      #{@dim}# List open games#{@reset}
      #{@white}Games.list_open_games!()#{@reset}

      #{@dim}# Another player joins#{@reset}
      #{@white}game = Games.join!(game, actor: o)#{@reset}

      #{@dim}# Look up a game by id#{@reset}
      #{@white}Games.get_by_id!(game.id)#{@reset}
    """)

    :ok
  end

  @doc """
  Load and display all important game information: state, players, board, and available moves.
  """
  def show(game) do
    game =
      Ash.load!(
        game,
        [
          :state,
          :board,
          :available_fields,
          :move_count,
          :winner_id,
          :player_o,
          :player_x
        ],
        authorize?: false
      )

    IO.puts("")
    IO.puts("  #{@bright}#{@cyan}Game ##{game.id}#{@reset}")
    IO.puts("")

    state_color = if game.state == :won, do: @green, else: @white
    IO.puts("  #{@dim}State:#{@reset}    #{state_color}#{game.state}#{@reset}")
    IO.puts("  #{@dim}Moves:#{@reset}    #{@white}#{game.move_count}#{@reset}")

    IO.puts("  #{@dim}Player O:#{@reset} #{@yellow}#{game.player_o.name}#{@reset}")

    if game.player_x do
      IO.puts("  #{@dim}Player X:#{@reset} #{@green}#{game.player_x.name}#{@reset}")
    end

    if game.state == :won do
      winner = if game.winner_id == game.player_o.id, do: game.player_o, else: game.player_x
      IO.puts("  #{@dim}Winner:#{@reset}   #{@bright}#{@green}#{winner.name}#{@reset}")
    end

    IO.puts("")
    IO.puts("  #{@bright}Board#{@reset}")
    board(game)

    if game.state == :active do
      fields = game.available_fields |> Enum.sort() |> Enum.join(", ")
      IO.puts("  #{@dim}Available:#{@reset} #{@white}#{fields}#{@reset}")
      IO.puts("")
    end

    :ok
  end

  @doc """
  Print an ASCII representation of the current board.

  Played fields show `X` or `O` (color-coded), empty fields show their number (0-8).
  Uses `Xo.Games.GameSummary.board_text/1` for layout, then applies ANSI colors.
  """
  def board(game) do
    game = Ash.load!(game, :board)

    colored =
      Xo.Games.GameSummary.board_text(game)
      |> String.replace("X", "#{@green}X#{@reset}")
      |> String.replace("O", "#{@yellow}O#{@reset}")
      |> String.replace("_", "#{@dim}_#{@reset}")

    IO.puts("")
    IO.puts(colored)
    IO.puts("")
    :ok
  end

  @doc """
  Print examples for making moves and playing a full game.
  """
  def moves do
    IO.puts("""

    #{@bright}#{@cyan}Moves & Gameplay#{@reset}

      #{@dim}# The board fields are numbered 0-8:
      #
      #   0 | 1 | 2
      #  ---+---+---
      #   3 | 4 | 5
      #  ---+---+---
      #   6 | 7 | 8
      #{@reset}

      #{@dim}# Play a full game:#{@reset}
      #{@white}game = Games.create_game!(actor: x)#{@reset}
      #{@white}game = Games.join!(game, actor: o)#{@reset}
      #{@white}game = Games.make_move!(game, 0, actor: x)#{@reset}
      #{@white}game = Games.make_move!(game, 4, actor: o)#{@reset}
      #{@white}game = Games.make_move!(game, 1, actor: x)#{@reset}
      #{@white}game = Games.make_move!(game, 3, actor: o)#{@reset}
      #{@white}game = Games.make_move!(game, 2, actor: x)#{@reset}
      #{@dim}# x wins with top row!#{@reset}
    """)

    :ok
  end
end
