defmodule WhiskeySour.Core.Engines.InMemoryEngine do
  @moduledoc """
  The `InMemoryEngine` module provides an in-memory engine for executing process instances.
  """

  alias WhiskeySour.Core.Engine.EngineFunctor
  alias WhiskeySour.Core.Free
  alias WhiskeySour.Core.ProcessDefinition
  alias WhiskeySour.Core.ProcessInstance

  defstruct ~w(reverse_audit_log unique_key_generator_fun event_subscriptions workflow_definitions)a

  def new,
    do: %__MODULE__{
      event_subscriptions: [],
      workflow_definitions: %{},
      reverse_audit_log: [],
      unique_key_generator_fun: fn -> 1 end
    }

  def run(engine, free) do
    {next_engine, _next_free} = do_run(engine, free)
    next_engine
  end

  defp do_run(engine, %Free{functor: nil, value: value}), do: {engine, value}

  defp do_run(engine, %Free{functor: %EngineFunctor{operation: :activate_process, args: args}}) do
    %{bpmn_process_id: bpmn_process_id, process_key: process_key} = args
    {key, next_engine} = get_and_update_next_key!(engine)

    activating_event = %{
      state: :element_activating,
      element_id: bpmn_process_id,
      element_instance_key: key,
      flow_scope_key: :none,
      element_name: :undefined,
      element_type: :process
    }

    activated_event = %{
      state: :element_activated,
      element_id: bpmn_process_id,
      element_instance_key: key,
      flow_scope_key: :none,
      element_name: :undefined,
      element_type: :process
    }

    next_reverse_audit_log = [activated_event, activating_event | next_engine.reverse_audit_log]
    next_engine = %{next_engine | reverse_audit_log: next_reverse_audit_log}

    process_instance =
      ProcessInstance.new(
        key: key,
        process_key: process_key,
        bpmn_process_id: bpmn_process_id,
        state: :active
      )

    do_run(next_engine, Free.return({:ok, process_instance}))
  end

  defp do_run(engine, %Free{functor: %EngineFunctor{operation: :activate_start_event, args: args}}) do
    %{process_instance: process_instance} = args
    {key, next_engine} = get_and_update_next_key!(engine)

    with {:ok, %{definition: process_definition}} <-
           fetch_process_definition_assigns_by_key(engine,
             process_key: process_instance.process_key,
             bpmn_process_id: process_instance.bpmn_process_id
           ),
         {:ok, start_event_def} <- ProcessDefinition.fetch_start_event(process_definition) do
      next_engine = update_activate_start_event_logs(next_engine, key, process_instance.key, start_event_def)
      do_run(next_engine, Free.return({:ok, process_instance}))
    else
      {:error, error} ->
        do_run(next_engine, Free.return({:error, error}))
    end
  end

  defp do_run(engine, %Free{functor: %EngineFunctor{operation: :subscribe, args: args}}) do
    event_names = Map.fetch!(args, :event_names)
    event_handler = Map.fetch!(args, :event_handler)

    event_subscription = %{event_names: event_names, event_handler: event_handler}
    next_engine = %{engine | event_subscriptions: [event_subscription | engine.event_subscriptions]}

    do_run(next_engine, Free.return(:ok))
  end

  defp do_run(engine, %Free{functor: %EngineFunctor{operation: :deploy_definition, args: args}}) do
    %{definition: definition} = args
    process_definition_id = definition.id
    {key, next_engine} = get_and_update_next_key!(engine)

    next_workflow_definitions =
      Map.update(
        engine.workflow_definitions,
        process_definition_id,
        [
          %{
            version: 1,
            definition: definition,
            key: key
          }
        ],
        fn
          current_workflow_definitions_for_id ->
            last_deployed_process_definition = Enum.max_by(current_workflow_definitions_for_id, & &1.version)
            next_version_id = last_deployed_process_definition.version + 1
            next_deployed_process_definition = %{version: next_version_id, definition: definition, key: key}
            [next_deployed_process_definition | current_workflow_definitions_for_id]
        end
      )

    next_engine = %{next_engine | workflow_definitions: next_workflow_definitions}

    publish_event(next_engine, %{
      event_name: :process_deployed,
      event_payload: %{
        key: 1,
        workflows: [%{bpmn_process_id: process_definition_id, version: 1, process_key: 2}]
      }
    })

    do_run(next_engine, Free.return({:ok, next_engine}))
  end

  defp do_run(engine, %Free{
         functor: %EngineFunctor{operation: :fetch_process_definition_key, args: %{bpmn_process_id: bpmn_process_id}}
       }) do
    case fetch_lastest_process_assigns(engine, bpmn_process_id: bpmn_process_id) do
      {:ok, assigns} ->
        %{key: process_key} = assigns
        do_run(engine, Free.return({:ok, %{process_key: process_key}}))

      {:error, :process_definition_not_found} = error ->
        do_run(engine, Free.return(error))
    end
  end

  defp do_run(engine, %Free{functor: {:bind, free, f}}) do
    {next_engine, next_free} = do_run(engine, free)
    do_run(next_engine, f.(next_free))
  end

  def publish_event(engine, event) do
    engine.event_subscriptions
    |> Enum.filter(fn subscription -> Enum.member?(subscription.event_names, event.event_name) end)
    |> Enum.each(fn subscription -> subscription.event_handler.(event) end)
  end

  defp update_activate_start_event_logs(engine, key, process_id, start_event_def) do
    %{id: element_id, name: element_name} = start_event_def

    next_reverse_audit_log =
      for state <- [:element_activating, :element_activated, :element_completing, :element_completed],
          reduce: engine.reverse_audit_log do
        reverse_audit_log ->
          [
            %{
              state: state,
              element_id: element_id,
              element_instance_key: key,
              flow_scope_key: process_id,
              element_name: element_name,
              element_type: :start_event
            }
            | reverse_audit_log
          ]
      end

    %{engine | reverse_audit_log: next_reverse_audit_log}
  end

  defp get_and_update_next_key!(engine) do
    key = engine.unique_key_generator_fun.()
    {key, %{engine | unique_key_generator_fun: fn -> key + 1 end}}
  end

  def fetch_process_definition_assigns_by_key(engine, opts) do
    bpmn_process_id = Keyword.fetch!(opts, :bpmn_process_id)
    process_key = Keyword.fetch!(opts, :process_key)

    case Map.get(engine.workflow_definitions, bpmn_process_id) do
      nil ->
        {:error, :process_definition_not_found}

      workflow_definitions ->
        case Enum.find(workflow_definitions, &(&1.key == process_key)) do
          nil ->
            {:error, :process_definition_not_found}

          process_definition ->
            {:ok, process_definition}
        end
    end
  end

  def fetch_lastest_process_assigns(engine, opts) do
    bpmn_process_id = Keyword.fetch!(opts, :bpmn_process_id)

    case Map.get(engine.workflow_definitions, bpmn_process_id) do
      nil ->
        {:error, :process_definition_not_found}

      workflow_definitions ->
        {:ok, Enum.max_by(workflow_definitions, & &1.version)}
    end
  end

  def audit_log(engine), do: Enum.reverse(engine.reverse_audit_log)
end
