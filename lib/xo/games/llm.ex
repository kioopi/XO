defmodule Xo.Games.LLM do
  @moduledoc "Builds the LLM model for the AI commentator based on application config."

  def build do
    provider = Application.get_env(:xo, :llm_provider, :anthropic)
    build(provider)
  end

  defp build(:anthropic) do
    api_key =
      Application.get_env(:xo, :anthropic_api_key) ||
        raise "ANTHROPIC_API_KEY is required when llm_provider is :anthropic"

    LangChain.ChatModels.ChatAnthropic.new!(%{
      # , "claude-sonnet-4-20250514"),
      model: Application.get_env(:xo, :anthropic_model, "anthropic:claude-3-haiku-20240307"),
      api_key: api_key
    })
  end

  defp build(:openai) do
    api_key =
      Application.get_env(:xo, :openai_api_key) ||
        raise "OPENAI_API_KEY is required when llm_provider is :openai"

    LangChain.ChatModels.ChatOpenAI.new!(%{
      model: Application.get_env(:xo, :openai_model, "gpt-4o-mini"),
      api_key: api_key
    })
  end
end
