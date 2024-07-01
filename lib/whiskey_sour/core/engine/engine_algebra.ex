defmodule WhiskeySour.Core.Engine.EngineAlgebra do
  @moduledoc false
  alias WhiskeySour.Core.Engine.EngineFunctor
  alias WhiskeySour.Core.Free

  def create_instance(opts) when is_list(opts) do
    bpmn_process_id = Keyword.fetch!(opts, :bpmn_process_id)

    Free.bind(fetch_process_definition_key(bpmn_process_id: bpmn_process_id), fn
      {:ok, %{workflow_key: workflow_key}} ->
        Free.bind(activate_process(bpmn_process_id: bpmn_process_id, workflow_key: workflow_key), fn
          {:ok, process_instance} ->
            Free.bind(
              activate_start_event(process_instance: process_instance),
              fn
                {:ok, process_instance} -> Free.return({:ok, process_instance})
                {:error, :process_definition_not_found} -> Free.return({:error, :process_definition_not_found})
              end
            )
        end)

      {:error, :process_definition_not_found} ->
        Free.return({:error, :process_definition_not_found})
    end)
  end

  def deploy_definition(opts) do
    definition = Keyword.fetch!(opts, :definition)
    Free.lift(EngineFunctor.new(:deploy_definition, %{definition: definition}))
  end

  def fetch_process_definition_key(opts) do
    bpmn_process_id = Keyword.fetch!(opts, :bpmn_process_id)

    Free.lift(EngineFunctor.new(:fetch_process_definition_key, %{bpmn_process_id: bpmn_process_id}))
  end

  def activate_process(opts) do
    required_attrs = [:bpmn_process_id, :workflow_key]

    args =
      opts
      |> Keyword.validate!(required_attrs)
      |> Keyword.take(required_attrs)
      |> Map.new()

    Free.lift(EngineFunctor.new(:activate_process, args))
  end

  def activate_start_event(args) do
    required_attrs = [:process_instance]

    args =
      args
      |> Keyword.validate!(required_attrs)
      |> Keyword.take(required_attrs)
      |> Map.new()

    Free.lift(EngineFunctor.new(:activate_start_event, args))
  end

  def subscribe(opts) do
    event_names =
      opts
      |> Keyword.fetch!(:to)
      |> List.wrap()

    event_handler = Keyword.fetch!(opts, :event_handler)

    Free.lift(
      EngineFunctor.new(:subscribe, %{
        event_names: event_names,
        event_handler: event_handler
      })
    )
  end
end
