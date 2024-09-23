defmodule WhiskeySour.Core.Engine.EngineFunctor.DeployDefinition do
  @moduledoc """
  Represents the operation to deploy a new process definition.
  """
  defstruct [:definition, :correlation_ref]

  def new(opts) do
    fields = Keyword.validate!(opts, [:definition, correlation_ref: nil])
    struct(__MODULE__, fields)
  end

  defimpl WhiskeySour.Core.Engines.InMemoryEngine.Interpreter do
    alias WhiskeySour.Core.Engines.InMemoryEngine

    def eval(%{definition: definition, correlation_ref: correlation_ref}, engine, next_fun) do
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
          workflows: [%{bpmn_process_id: process_definition_id, version: 1, process_key: key}]
        },
        correlation_ref: correlation_ref
      })

      next_fun.(next_engine, WhiskeySour.Core.Free.return({:ok, next_engine}))
    end
  end
end
