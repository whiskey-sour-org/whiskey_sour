defmodule WhiskeySour.Core.Engines.InMemoryEngine do
  @moduledoc """
  The `InMemoryEngine` module provides an in-memory engine for executing process instances.
  """

  alias WhiskeySour.Core.Engine.EngineFunctor
  alias WhiskeySour.Core.Free

  defstruct ~w(reverse_audit_log unique_key_generator_fun event_subscriptions process_definitions)a

  def new,
    do: %__MODULE__{
      event_subscriptions: [],
      process_definitions: %{},
      reverse_audit_log: [],
      unique_key_generator_fun: fn -> 1 end
    }

  def run(engine, free) do
    {next_engine, _next_free} = do_run(engine, free)
    next_engine
  end

  defp do_run(engine, %Free{functor: nil, value: value}), do: {engine, value}

  defp do_run(engine, %Free{functor: %EngineFunctor{operation: :activate_process, args: [element_id]}}) do
    {key, next_engine} = get_and_update_next_key!(engine)

    activating_event = %{
      state: :element_activating,
      element_id: element_id,
      element_instance_key: key,
      flow_scope_key: :none,
      element_name: :undefined,
      element_type: :process
    }

    activated_event = %{
      state: :element_activated,
      element_id: element_id,
      element_instance_key: key,
      flow_scope_key: :none,
      element_name: :undefined,
      element_type: :process
    }

    next_reverse_audit_log = [activated_event, activating_event | next_engine.reverse_audit_log]
    next_engine = %{next_engine | reverse_audit_log: next_reverse_audit_log}

    do_run(next_engine, Free.return(key))
  end

  defp do_run(engine, %Free{functor: %EngineFunctor{operation: :activate_start_event, args: args}}) do
    {key, next_engine} = get_and_update_next_key!(engine)

    process_id = Keyword.fetch!(args, :process_id)
    element_id = Keyword.fetch!(args, :element_id)
    element_name = Keyword.get(args, :element_name, :undefined)
    next_engine = update_activate_start_event_logs(next_engine, key, process_id, element_id, element_name)

    do_run(next_engine, Free.return(key))
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

    next_process_definitions =
      Map.update(
        engine.process_definitions,
        process_definition_id,
        [
          %{
            version: 1,
            definition: definition
          }
        ],
        fn
          current_process_definitions_for_id ->
            last_deployed_process_definition = Enum.max_by(current_process_definitions_for_id, & &1.version)
            next_version_id = last_deployed_process_definition.version + 1
            next_deployed_process_definition = %{version: next_version_id, definition: definition}
            [next_deployed_process_definition | current_process_definitions_for_id]
        end
      )

    next_engine = %{engine | process_definitions: next_process_definitions}

    publish_event(next_engine, %{
      event_name: :process_deployed,
      event_payload: %{
        key: 1,
        workflows: [%{bpmn_process_id: process_definition_id, version: 1, workflow_key: 2}]
      }
    })

    do_run(next_engine, Free.return({:ok, next_engine}))
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

  defp update_activate_start_event_logs(engine, key, process_id, element_id, element_name) do
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

  def audit_log(engine), do: Enum.reverse(engine.reverse_audit_log)
end
