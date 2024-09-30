defmodule WhiskeySour.Core.Engine.EngineFunctor.FetchProcessDefinitionKey do
  @moduledoc """
  Represents the operation to fetch a process definition.
  """

  @type process_definition_id :: String.t()
  @type correlation_ref :: any()
  @type t :: %__MODULE__{
          process_definition_id: String.t(),
          correlation_ref: any()
        }

  defstruct process_definition_id: "", correlation_ref: nil

  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    fields = Keyword.validate!(opts, [:process_definition_id, correlation_ref: nil])
    struct(__MODULE__, fields)
  end

  defimpl WhiskeySour.Core.Engines.InMemoryEngine.Interpreter do
    alias WhiskeySour.Core.Engine.EngineFunctor.FetchProcessDefinitionKey
    alias WhiskeySour.Core.Engines.InMemoryEngine
    alias WhiskeySour.Core.Free

    @spec eval(FetchProcessDefinitionKey.t(), map(), (map(), any() -> any())) :: any()
    def eval(%FetchProcessDefinitionKey{process_definition_id: process_definition_id}, engine, next_fun)
        when is_binary(process_definition_id) and is_function(next_fun, 2) do
      case InMemoryEngine.fetch_lastest_process_assigns(engine, process_definition_id: process_definition_id) do
        {:ok, assigns} ->
          %{key: process_key} = assigns
          next_fun.(engine, Free.return({:ok, %{process_key: process_key}}))

        {:error, :process_definition_not_found} = error ->
          next_fun.(engine, Free.return(error))
      end
    end
  end
end
