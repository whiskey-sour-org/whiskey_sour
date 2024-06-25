defmodule WhiskeySour.Core.Engines.InMemoryEngine do
  @moduledoc """
  The `InMemoryEngine` module provides an in-memory engine for executing process instances.
  """

  alias WhiskeySour.Core.ProcessInstance.Free
  alias WhiskeySour.Core.ProcessInstance.ProcessFunctor

  defstruct ~w(reverse_audit_log unique_key_generator_fun)a

  def new, do: %__MODULE__{reverse_audit_log: [], unique_key_generator_fun: fn -> 1 end}

  def run(engine, free) do
    {next_engine, _next_free} = do_run(engine, free)
    next_engine
  end

  defp do_run(engine, %Free{functor: nil, value: value}), do: {engine, value}

  defp do_run(engine, %Free{functor: %ProcessFunctor{operation: :activate_process, args: [element_id]}}) do
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

  defp do_run(engine, %Free{functor: %ProcessFunctor{operation: :activate_start_event, args: args}}) do
    {key, next_engine} = get_and_update_next_key!(engine)

    process_id = Keyword.fetch!(args, :process_id)
    element_id = Keyword.fetch!(args, :element_id)
    element_name = Keyword.get(args, :element_name, :undefined)

    reverse_start_events =
      for state <- Enum.reverse([:activating, :activated, :completing, :completed]) do
        %{
          state: :"element_#{state}",
          element_id: element_id,
          element_instance_key: key,
          flow_scope_key: process_id,
          element_name: element_name,
          element_type: :start_event
        }
      end

    next_reverse_audit_log = reverse_start_events ++ next_engine.reverse_audit_log
    next_engine = %{next_engine | reverse_audit_log: next_reverse_audit_log}

    do_run(next_engine, Free.return(key))
  end

  defp do_run(engine, %Free{functor: {:bind, free, f}}) do
    {next_engine, next_free} = do_run(engine, free)
    do_run(next_engine, f.(next_free))
  end

  defp get_and_update_next_key!(engine) do
    key = engine.unique_key_generator_fun.()
    {key, %{engine | unique_key_generator_fun: fn -> key + 1 end}}
  end

  def audit_log(engine), do: Enum.reverse(engine.reverse_audit_log)
end
