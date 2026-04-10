defmodule Xo.Games.Commentator.GameFragment do
  use Spark.Dsl.Fragment,
    of: Ash.Resource,
    authorizers: [Ash.Policy.Authorizer]

  require AshAi.Actions

  actions do
    @commentator_system_prompt """
    You are a witty and entertaining tic-tac-toe commentator in a game chat room.
    Keep your commentary to 1-2 short sentences. Be fun and engaging but not annoying.
    Reference players by name when possible. Do NOT use markdown formatting. Write plain text only
    """

    action :generate_commentary, :string do
      description """
      Generate commentary about a game event. Dispatches to either the tools-based or
      context-based action depending on the :commentator_use_tools application config.
      """

      argument :game_id, :integer do
        allow_nil? false
        description "The ID of the game to comment on."
      end

      argument :event_description, :string do
        allow_nil? false
        description "What just happened in the game."
      end

      run Xo.Games.Commentator.GenerateCommentary
    end

    action :generate_commentary_with_context, :string do
      description """
      Generate commentary about a game event. Game context is provided directly as text.
      """

      argument :game_context, :string do
        allow_nil? false
        description "A summary of the current game state including board, players, and moves."
      end

      argument :event_description, :string do
        allow_nil? false
        description "What just happened in the game."
      end

      run AshAi.Actions.prompt(
            fn _input, _context -> Xo.Games.LLM.build() end,
            adapter: AshAi.Actions.Prompt.Adapter.RequestJson,
            tools: false,
            prompt:
              {@commentator_system_prompt,
               "<%= @input.arguments.game_context %>\n\nEvent: <%= @input.arguments.event_description %>"}
          )
    end

    action :generate_commentary_with_tools, :string do
      description """
      Generate commentary about a game event using AshAi tools to query game state.
      The LLM can use read_game and read_moves tools to look up the current board, players, and move history.
      """

      argument :game_id, :integer do
        allow_nil? false
        description "The ID of the game to comment on."
      end

      argument :event_description, :string do
        allow_nil? false
        description "What just happened in the game."
      end

      run AshAi.Actions.prompt(
            fn _input, _context -> Xo.Games.LLM.build() end,
            adapter: AshAi.Actions.Prompt.Adapter.RequestJson,
            tools: [:read_game, :read_moves],
            prompt:
              {@commentator_system_prompt,
               "Game ID: <%= @input.arguments.game_id %>\nEvent: <%= @input.arguments.event_description %>\n\nUse the available tools to look up the current game state, then produce a brief commentary."}
          )
    end
  end

  policies do
    policy action([
             :generate_commentary,
             :generate_commentary_with_context,
             :generate_commentary_with_tools
           ]) do
      description "Authenticated users (including the bot) can generate commentary."
      authorize_if actor_present()
    end
  end
end
