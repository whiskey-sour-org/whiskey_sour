defmodule WhiskeySour.Core.ProcessInstanceTest do
  use ExUnit.Case

  alias WhiskeySour.Core.ProcessDefinition
  alias WhiskeySour.Core.ProcessInstance

  defmodule TestAuditLogger do
    @moduledoc false
    alias WhiskeySour.Core.ProcessInstance.Free
    alias WhiskeySour.Core.ProcessInstance.ProcessFunctor
    # The interpreter for the free monad

    def run(free, log \\ [], key_generator_map \\ %{key: 1}) do
      {_value, reverse_log, _next_key_generator_map} = do_run(free, log, key_generator_map)
      Enum.reverse(reverse_log)
    end

    defp do_run(%Free{functor: nil, value: value}, log, key_generator_map), do: {value, log, key_generator_map}

    defp do_run(%Free{functor: %ProcessFunctor{operation: :activate_process, args: [element_id]}}, log, key_generator_map) do
      {key, next_key_generator_map} =
        Map.get_and_update!(key_generator_map, :key, fn v -> {v, v + 1} end)

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

      new_log = [activated_event, activating_event | log]

      key
      |> Free.return()
      |> do_run(new_log, next_key_generator_map)
    end

    defp do_run(%Free{functor: %ProcessFunctor{operation: :activate_start_event, args: args}}, log, key_generator_map) do
      {key, next_key_generator_map} =
        Map.get_and_update!(key_generator_map, :key, fn v -> {v, v + 1} end)

      process_id = Keyword.fetch!(args, :process_id)
      element_id = Keyword.fetch!(args, :element_id)
      element_name = Keyword.get(args, :element_name, :undefined)

      activating_event = %{
        state: :element_activating,
        element_id: element_id,
        element_instance_key: key,
        flow_scope_key: process_id,
        element_name: element_name,
        element_type: :start_event
      }

      activated_event = %{
        state: :element_activated,
        element_id: element_id,
        element_instance_key: key,
        flow_scope_key: process_id,
        element_name: element_name,
        element_type: :start_event
      }

      new_log = [activated_event, activating_event | log]

      key
      |> Free.return()
      |> do_run(new_log, next_key_generator_map)
    end

    defp do_run(%Free{functor: {:bind, free, f}}, log, key_generator_map) do
      {free_value, new_log, next_key_generator_map} = do_run(free, log, key_generator_map)
      do_run(f.(free_value), new_log, next_key_generator_map)
    end
  end

  doctest WhiskeySour.Core.ProcessInstance

  describe "start w/ order_process" do
    test "should return a program that can produce an audit log" do
      start_program = ProcessInstance.start(definition: sample_order_process_definition())

      audit_log = TestAuditLogger.run(start_program)

      assert Enum.at(audit_log, 0) == %{
               element_id: "order_process",
               element_instance_key: 1,
               flow_scope_key: :none,
               state: :element_activating,
               element_name: :undefined,
               element_type: :process
             }

      assert Enum.at(audit_log, 1) == %{
               element_id: "order_process",
               element_instance_key: 1,
               flow_scope_key: :none,
               state: :element_activated,
               element_name: :undefined,
               element_type: :process
             }

      assert Enum.at(audit_log, 2) == %{
               element_id: "start_event_1",
               element_instance_key: 2,
               flow_scope_key: 1,
               state: :element_activating,
               element_name: "Start Event",
               element_type: :start_event
             }

      assert Enum.at(audit_log, 3) == %{
               element_id: "start_event_1",
               element_instance_key: 2,
               flow_scope_key: 1,
               state: :element_activated,
               element_name: "Start Event",
               element_type: :start_event
             }
    end
  end

  describe "start w/ trip_process" do
    test "should return a program that can produce an audit log" do
      start_program = ProcessInstance.start(definition: sample_trip_process_definition())

      audit_log = TestAuditLogger.run(start_program)

      assert Enum.at(audit_log, 0) == %{
               element_id: "trip_flow",
               element_instance_key: 1,
               flow_scope_key: :none,
               state: :element_activating,
               element_name: :undefined,
               element_type: :process
             }

      assert Enum.at(audit_log, 1) == %{
               element_id: "trip_flow",
               element_instance_key: 1,
               flow_scope_key: :none,
               state: :element_activated,
               element_name: :undefined,
               element_type: :process
             }

      assert Enum.at(audit_log, 2) == %{
               element_id: "start_event_42",
               element_instance_key: 2,
               flow_scope_key: 1,
               state: :element_activating,
               element_name: :undefined,
               element_type: :start_event
             }

      assert Enum.at(audit_log, 3) == %{
               element_id: "start_event_42",
               element_instance_key: 2,
               flow_scope_key: 1,
               state: :element_activated,
               element_name: :undefined,
               element_type: :start_event
             }
    end
  end

  def sample_order_process_definition do
    [id: "order_process", name: "Order Processing"]
    |> ProcessDefinition.new()
    |> ProcessDefinition.add_event(%{id: "start_event_1", type: :start_event, name: "Start Event"})
    |> ProcessDefinition.add_activity(%{id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"})
    |> ProcessDefinition.add_event(%{id: "end_event_1", type: :end_event, name: "End Event"})
    |> ProcessDefinition.add_sequence_flow(%{id: "flow1", source_ref: "start_event_1", target_ref: "review_order"})
    |> ProcessDefinition.add_sequence_flow(%{id: "flow2", source_ref: "review_order", target_ref: "end_event_1"})
  end

  def sample_trip_process_definition do
    [id: "trip_flow", name: "Trip Flow"]
    |> ProcessDefinition.new()
    |> ProcessDefinition.add_event(%{id: "start_event_42", type: :start_event})
    |> ProcessDefinition.add_activity(%{id: "activity_1", type: :user_task, name: "Book flight"})
    |> ProcessDefinition.add_sequence_flow(%{
      id: "flow_1",
      source_ref: "start_event_42",
      target_ref: "activity_1"
    })
  end
end
