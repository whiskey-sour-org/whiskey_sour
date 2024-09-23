defmodule WhiskeySour.Core.Engines.InMemoryEngine do
  @moduledoc """
  The `InMemoryEngine` module provides an in-memory engine for executing and managing workflow instances.

  ## Features

  - Deploy BPMN process definitions.
  - Create and manage workflow instances.
  - Subscribe to and publish workflow events.
  - Maintain audit logs and track user tasks.
  """

  alias WhiskeySour.Core.Engine.EngineFunctor
  alias WhiskeySour.Core.Engines.InMemoryEngine.Interpreter
  alias WhiskeySour.Core.Free
  alias WhiskeySour.Core.ProcessDefinition
  alias WhiskeySour.Core.ProcessInstance

  defstruct ~w(reverse_audit_log unique_key_generator_fun event_subscriptions process_definition_deployments user_tasks)a

  @doc """
  Creates a new instance of the InMemoryEngine.
  """
  @spec new() :: %WhiskeySour.Core.Engines.InMemoryEngine{
          event_subscriptions: %{},
          process_definition_deployments: %{},
          reverse_audit_log: [],
          unique_key_generator_fun: (-> 1),
          user_tasks: []
        }
  def new,
    do: %__MODULE__{
      event_subscriptions: %{},
      process_definition_deployments: %{},
      reverse_audit_log: [],
      unique_key_generator_fun: fn -> 1 end,
      user_tasks: []
    }

  def run(engine, free) do
    {next_engine, _next_free} = do_run(engine, free)
    next_engine
  end

  defp do_run(engine, %Free{functor: nil, value: value}), do: {engine, value}

  defp do_run(engine, %Free{functor: {:bind, free, f}}) do
    {next_engine, next_free} = do_run(engine, free)
    do_run(next_engine, f.(next_free))
  end

  defp do_run(engine, %Free{functor: %EngineFunctor{operation: operation, args: args}}) do
    case operation do
      :deploy_definition -> handle_deploy_definition(engine, args)
      :fetch_process_definition_key -> handle_fetch_process_definition_key(engine, args)
      :activate_process -> handle_activate_process(engine, args)
      :activate_start_event -> handle_activate_start_event(engine, args)
      :take_next_flow -> handle_take_next_flow(engine, args)
      :activate_element -> handle_activate_element(engine, args)
      :subscribe -> handle_subscribe(engine, args)
      _ -> {:error, {:unknown_operation, operation}}
    end
  end

  defp do_run(engine, %Free{functor: %EngineFunctor.DeployDefinition{} = functor}) do
    Interpreter.eval(functor, engine, &do_run/2)
  end

  defp handle_activate_process(engine, args) do
    %{bpmn_process_id: bpmn_process_id, process_key: process_key, correlation_ref: correlation_ref} = args
    {process_instance_key, next_engine} = get_and_update_next_key!(engine)

    activating_event = %{
      state: :element_activating,
      element_id: bpmn_process_id,
      element_instance_key: process_instance_key,
      flow_scope_key: :none,
      element_name: :undefined,
      element_type: :process
    }

    activated_event = %{
      state: :element_activated,
      element_id: bpmn_process_id,
      element_instance_key: process_instance_key,
      flow_scope_key: :none,
      element_name: :undefined,
      element_type: :process
    }

    next_reverse_audit_log = [activated_event, activating_event | next_engine.reverse_audit_log]
    next_engine = %{next_engine | reverse_audit_log: next_reverse_audit_log}

    process_instance =
      ProcessInstance.new(
        key: process_instance_key,
        process_key: process_key,
        bpmn_process_id: bpmn_process_id,
        state: :active
      )

    publish_event(next_engine, %{
      event_name: :process_activated,
      event_payload: %{
        key: process_instance_key,
        process_instance_key: process_instance_key
      },
      correlation_ref: correlation_ref
    })

    next_functor =
      EngineFunctor.new(:activate_start_event, %{process_instance: process_instance})

    do_run(next_engine, Free.lift(next_functor))
  end

  defp handle_activate_start_event(engine, args) do
    %{process_instance: process_instance} = args
    {key, next_engine} = get_and_update_next_key!(engine)

    with {:ok, %{definition: process_definition}} <-
           fetch_process_definition_assigns_by_key(engine,
             process_key: process_instance.process_key,
             bpmn_process_id: process_instance.bpmn_process_id
           ),
         {:ok, start_event_def} <- ProcessDefinition.fetch_start_event(process_definition) do
      next_engine = update_activate_start_event_logs(next_engine, key, process_instance.key, start_event_def)

      next_functor =
        EngineFunctor.new(:take_next_flow, %{
          process_instance: process_instance,
          definition: process_definition,
          current_element_id: start_event_def.id
        })

      do_run(next_engine, Free.lift(next_functor))
    else
      {:error, error} ->
        do_run(next_engine, Free.return({:error, error}))
    end
  end

  defp handle_take_next_flow(engine, args) do
    %{process_instance: process_instance, definition: process_definition, current_element_id: current_element_id} = args
    {key, next_engine} = get_and_update_next_key!(engine)

    with {:ok, sequence_flow_def} <-
           ProcessDefinition.fetch_sequence_flow_by_source_ref(process_definition, current_element_id),
         {:ok, target_element_def} <-
           ProcessDefinition.fetch_element_by_id(process_definition, sequence_flow_def.target_ref) do
      next_engine = update_sequence_flow_logs(next_engine, key, process_instance.key, sequence_flow_def)

      next_functor =
        EngineFunctor.new(:activate_element, %{
          process_instance: process_instance,
          element_def: target_element_def
        })

      do_run(next_engine, Free.lift(next_functor))
    else
      {:error, error} ->
        do_run(next_engine, Free.return({:error, error}))
    end
  end

  defp handle_activate_element(engine, args) do
    %{process_instance: process_instance, element_def: element_def} = args
    {key, next_engine} = get_and_update_next_key!(engine)

    case element_def.type do
      :user_task ->
        next_engine = activate_user_task(next_engine, key, process_instance.key, element_def)

        do_run(next_engine, Free.return({:ok, process_instance}))
    end
  end

  defp handle_subscribe(engine, args) do
    event_names = Map.fetch!(args, :event_names)
    event_handler = Map.fetch!(args, :event_handler)

    updated_subscriptions =
      Enum.reduce(event_names, engine.event_subscriptions, fn event_name, acc ->
        Map.update(acc, event_name, [event_handler], &[event_handler | &1])
      end)

    next_engine = %{engine | event_subscriptions: updated_subscriptions}

    do_run(next_engine, Free.return(:ok))
  end

  defp handle_deploy_definition(engine, args) do
    %{definition: definition, correlation_ref: correlation_ref} = args
    process_definition_id = definition.id
    {key, next_engine} = get_and_update_next_key!(engine)

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

    publish_event(next_engine, %{
      event_name: :process_deployed,
      event_payload: %{
        key: key,
        workflows: [%{bpmn_process_id: process_definition_id, version: 1, process_key: key}]
      },
      correlation_ref: correlation_ref
    })

    do_run(next_engine, Free.return({:ok, next_engine}))
  end

  defp handle_fetch_process_definition_key(engine, %{bpmn_process_id: bpmn_process_id}) do
    case fetch_lastest_process_assigns(engine, bpmn_process_id: bpmn_process_id) do
      {:ok, assigns} ->
        %{key: process_key} = assigns
        do_run(engine, Free.return({:ok, %{process_key: process_key}}))

      {:error, :process_definition_not_found} = error ->
        do_run(engine, Free.return(error))
    end
  end

  def publish_event(engine, event) do
    engine.event_subscriptions
    |> Map.get(event.event_name, [])
    |> Enum.each(fn event_handler -> event_handler.(event) end)
  end

  defp update_activate_start_event_logs(engine, element_instance_key, flow_scope_key, start_event_def) do
    %{id: element_id, name: element_name} = start_event_def

    next_reverse_audit_log =
      for state <- [:element_activating, :element_activated, :element_completing, :element_completed],
          reduce: engine.reverse_audit_log do
        reverse_audit_log ->
          [
            %{
              state: state,
              element_id: element_id,
              element_instance_key: element_instance_key,
              flow_scope_key: flow_scope_key,
              element_name: element_name,
              element_type: :start_event
            }
            | reverse_audit_log
          ]
      end

    %{engine | reverse_audit_log: next_reverse_audit_log}
  end

  defp update_sequence_flow_logs(engine, element_instance_key, flow_scope_key, sequence_flow_def) do
    %{id: element_id} = sequence_flow_def

    next_reverse_audit_log = [
      %{
        state: :element_taken,
        element_id: element_id,
        element_instance_key: element_instance_key,
        flow_scope_key: flow_scope_key,
        element_name: :undefined,
        element_type: :sequence_flow
      }
      | engine.reverse_audit_log
    ]

    %{engine | reverse_audit_log: next_reverse_audit_log}
  end

  def activate_user_task(engine, element_instance_key, flow_scope_key, element_def) do
    %{id: element_id, name: element_name} = element_def

    engine
    |> get_and_update_next_key!()
    |> update_user_tasks(element_id, element_name, flow_scope_key, element_def)
    |> update_audit_log(element_id, element_instance_key, flow_scope_key, element_name, :user_task)
  end

  defp update_user_tasks({user_task_key, engine}, element_id, element_name, flow_scope_key, element_def) do
    user_task = %{
      key: user_task_key,
      element_id: element_id,
      element_name: element_name,
      assignee: Map.get(element_def, :assignee, :unassigned),
      state: :active,
      candidate_groups: Map.get(element_def, :candidate_groups, []),
      process_instance_key: flow_scope_key
    }

    %{engine | user_tasks: [user_task | engine.user_tasks]}
  end

  defp update_audit_log(engine, element_id, element_instance_key, flow_scope_key, element_name, element_type) do
    next_reverse_audit_log =
      for state <- [:element_activating, :element_activated],
          reduce: engine.reverse_audit_log do
        reverse_audit_log ->
          [
            %{
              state: state,
              element_id: element_id,
              element_instance_key: element_instance_key,
              flow_scope_key: flow_scope_key,
              element_name: element_name,
              element_type: element_type
            }
            | reverse_audit_log
          ]
      end

    %{engine | reverse_audit_log: next_reverse_audit_log}
  end

  def get_and_update_next_key!(engine) do
    key = engine.unique_key_generator_fun.()
    {key, %{engine | unique_key_generator_fun: fn -> key + 1 end}}
  end

  def fetch_process_definition_assigns_by_key(engine, opts) do
    bpmn_process_id = Keyword.fetch!(opts, :bpmn_process_id)
    process_key = Keyword.fetch!(opts, :process_key)

    case Map.get(engine.process_definition_deployments, bpmn_process_id) do
      nil ->
        {:error, :process_definition_not_found}

      process_definition_deployments ->
        case Enum.find(process_definition_deployments, &(&1.key == process_key)) do
          nil ->
            {:error, :process_definition_not_found}

          process_definition ->
            {:ok, process_definition}
        end
    end
  end

  def fetch_lastest_process_assigns(engine, opts) do
    bpmn_process_id = Keyword.fetch!(opts, :bpmn_process_id)

    case Map.get(engine.process_definition_deployments, bpmn_process_id) do
      nil ->
        {:error, :process_definition_not_found}

      process_definition_deployments ->
        {:ok, Enum.max_by(process_definition_deployments, & &1.version)}
    end
  end

  def audit_log(engine), do: Enum.reverse(engine.reverse_audit_log)

  def user_tasks_stream(engine) do
    Stream.map(engine.user_tasks, &format_user_task/1)
  end

  defp format_user_task(user_task) do
    %{
      assignee: user_task.assignee,
      candidate_groups: user_task.candidate_groups,
      element_id: user_task.element_id,
      element_instance_key: user_task.key,
      name: user_task.element_name,
      process_instance_key: user_task.process_instance_key,
      state: user_task.state
    }
  end

  def process_definitions_stream(engine) do
    Stream.flat_map(engine.process_definition_deployments, fn {_, process_definition_deployments} ->
      for %{version: version, definition: definition, key: process_key} <- process_definition_deployments do
        %{
          bpmn_process_id: definition.id,
          name: definition.name,
          process_key: process_key,
          version: version
        }
      end
    end)
  end

  defimpl Collectable do
    def into(engine) do
      collector_fun = fn
        engine, {:cont, free} ->
          __impl__(:for).run(engine, free)

        engine, :done ->
          engine

        _engine, :halt ->
          :ok
      end

      initial_acc = engine

      {initial_acc, collector_fun}
    end
  end
end
