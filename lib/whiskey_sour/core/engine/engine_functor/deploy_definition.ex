defmodule WhiskeySour.Core.Engine.EngineFunctor.DeployDefinition do
  @moduledoc """
  Represents the operation to deploy a new process definition.
  """

  @type definition :: map()
  @type correlation_ref :: any()
  @type t :: %__MODULE__{
          definition: map(),
          correlation_ref: any()
        }

  defstruct definition: %{}, correlation_ref: nil

  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    fields = Keyword.validate!(opts, [:definition, correlation_ref: nil])
    struct(__MODULE__, fields)
  end

  defimpl WhiskeySour.Core.Engines.InMemoryEngine.Interpreter, for: WhiskeySour.Core.Engine.EngineFunctor.DeployDefinition do
    alias WhiskeySour.Core.Engine.EngineFunctor.DeployDefinition
    alias WhiskeySour.Core.Engines.InMemoryEngine
    alias WhiskeySour.Core.Free

    @spec eval(DeployDefinition.t(), map(), (map(), any() -> any())) :: any()
    def eval(%DeployDefinition{definition: definition, correlation_ref: correlation_ref}, engine, next_fun)
        when is_map(definition) and is_function(next_fun, 2) do
      process_definition_id = definition.id
      {key, next_engine} = InMemoryEngine.get_and_update_next_key!(engine)

      next_process_definition_deployments =
        Map.update(
          engine.process_definition_deployments,
          process_definition_id,
          [
            %{
              version: 1,
              definition: definition,
              key: key
            }
          ],
          fn
            current_process_definition_deployments_for_id ->
              last_deployed_process_definition = Enum.max_by(current_process_definition_deployments_for_id, & &1.version)
              next_version_id = last_deployed_process_definition.version + 1
              next_deployed_process_definition = %{version: next_version_id, definition: definition, key: key}
              [next_deployed_process_definition | current_process_definition_deployments_for_id]
          end
        )

      next_engine = %{next_engine | process_definition_deployments: next_process_definition_deployments}

      InMemoryEngine.publish_event(next_engine, %{
        event_name: :process_deployed,
        event_payload: %{
          key: key,
          workflows: [%{process_definition_id: process_definition_id, version: 1, process_key: key}]
        },
        correlation_ref: correlation_ref
      })

      next_fun.(next_engine, Free.return({:ok, next_engine}))
    end
  end
end
