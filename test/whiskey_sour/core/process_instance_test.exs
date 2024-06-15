defmodule WhiskeySour.Core.ProcessInstanceTest do
  use ExUnit.Case

  alias WhiskeySour.Core.ProcessDefinition
  alias WhiskeySour.Core.ProcessInstance

  doctest WhiskeySour.Core.ProcessInstance

  describe "construct/1" do
    test "creates a new process instance for the given workflow definition" do
      definition = sample_order_process_definition()
      key = 42

      process_instance = ProcessInstance.construct(definition: definition, key: key)

      assert process_instance.key == key
      assert process_instance.definition == definition
      assert process_instance.uncommitted_events == []
      assert process_instance.committed_events == []
    end
  end

  describe "start/1" do
    test "should update uncommitted_events w/ sample_order_process" do
      process_instance =
        ProcessInstance.construct(definition: sample_order_process_definition(), key: 42)

      process_instance = ProcessInstance.start(process_instance)

      assert Enum.at(process_instance.uncommitted_events, 0) == %{
               element_id: "order_process",
               element_instance_key: process_instance.key,
               flow_scope_key: :none,
               state: :element_activating,
               element_name: :undefined,
               element_type: :process
             }

      assert Enum.at(process_instance.uncommitted_events, 1) == %{
               element_id: "order_process",
               element_instance_key: process_instance.key,
               flow_scope_key: :none,
               state: :element_activated,
               element_name: :undefined,
               element_type: :process
             }

      assert Enum.at(process_instance.uncommitted_events, 2) == %{
               element_id: "start_event_1",
               element_instance_key: :todo,
               flow_scope_key: process_instance.key,
               state: :element_activating,
               element_name: "Start Event",
               element_type: :start_event
             }
    end

    test "should update uncommitted_events w/ sample_trip_process" do
      process_instance =
        ProcessInstance.construct(definition: sample_trip_process_definition(), key: 43)

      process_instance = ProcessInstance.start(process_instance)

      assert Enum.at(process_instance.uncommitted_events, 0) == %{
               element_id: "trip_flow",
               element_instance_key: process_instance.key,
               flow_scope_key: :none,
               state: :element_activating,
               element_name: :undefined,
               element_type: :process
             }

      assert Enum.at(process_instance.uncommitted_events, 1) == %{
               element_id: "trip_flow",
               element_instance_key: process_instance.key,
               flow_scope_key: :none,
               state: :element_activated,
               element_name: :undefined,
               element_type: :process
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
    |> ProcessDefinition.add_event(%{id: "start_event_1", type: :start_event})
    |> ProcessDefinition.add_activity(%{id: "activity_1", type: :user_task, name: "Book flight"})
    |> ProcessDefinition.add_sequence_flow(%{
      id: "flow_1",
      source_ref: "start_event_1",
      target_ref: "activity_1"
    })
  end
end
