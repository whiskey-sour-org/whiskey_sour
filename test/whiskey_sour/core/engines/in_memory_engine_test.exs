defmodule WhiskeySour.Core.Engines.InMemoryEngineTest do
  use ExUnit.Case, async: true

  alias WhiskeySour.Core.Engine.EngineAlgebra
  alias WhiskeySour.Core.Engines.InMemoryEngine
  alias WhiskeySour.Core.ProcessDefinition

  doctest WhiskeySour.Core.Engines.InMemoryEngine

  describe "deploy order_process" do
    setup do
      definition =
        [id: "order_process", name: "Order Processing"]
        |> ProcessDefinition.new()
        |> ProcessDefinition.add_event(%{id: "start_event_1", type: :start_event, name: "Start Event"})
        |> ProcessDefinition.add_activity(%{id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"})
        |> ProcessDefinition.add_event(%{id: "end_event_1", type: :end_event, name: "End Event"})
        |> ProcessDefinition.add_sequence_flow(%{id: "flow1", source_ref: "start_event_1", target_ref: "review_order"})
        |> ProcessDefinition.add_sequence_flow(%{id: "flow2", source_ref: "review_order", target_ref: "end_event_1"})

      %{definition: definition}
    end

    test "should return deployed workflow info", %{definition: definition} do
      InMemoryEngine.new()
      |> InMemoryEngine.run(
        EngineAlgebra.subscribe(
          to: :process_deployed,
          event_handler: fn event ->
            send(self(), event)
          end
        )
      )
      |> InMemoryEngine.run(EngineAlgebra.deploy_definition(definition: definition))

      assert_received %{
        event_name: :process_deployed,
        event_payload: %{
          key: _key,
          workflows: [
            %{
              bpmn_process_id: "order_process",
              version: 1,
              workflow_key: _workflow_key
            }
          ]
        }
      }
    end
  end

  describe "start w/ order_process" do
    setup do
      definition =
        [id: "order_process", name: "Order Processing"]
        |> ProcessDefinition.new()
        |> ProcessDefinition.add_event(%{id: "start_event_1", type: :start_event, name: "Start Event"})
        |> ProcessDefinition.add_activity(%{id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"})
        |> ProcessDefinition.add_event(%{id: "end_event_1", type: :end_event, name: "End Event"})
        |> ProcessDefinition.add_sequence_flow(%{id: "flow1", source_ref: "start_event_1", target_ref: "review_order"})
        |> ProcessDefinition.add_sequence_flow(%{id: "flow2", source_ref: "review_order", target_ref: "end_event_1"})

      %{definition: definition}
    end

    test "should return expected workflow audit log", %{definition: definition} do
      audit_log =
        InMemoryEngine.new()
        |> InMemoryEngine.run(EngineAlgebra.create_instance(definition: definition))
        |> InMemoryEngine.audit_log()

      assert [
               %{
                 element_id: "order_process",
                 element_instance_key: 1,
                 flow_scope_key: :none,
                 state: :element_activating,
                 element_name: :undefined,
                 element_type: :process
               },
               %{
                 element_id: "order_process",
                 element_instance_key: 1,
                 flow_scope_key: :none,
                 state: :element_activated,
                 element_name: :undefined,
                 element_type: :process
               },
               %{
                 element_id: "start_event_1",
                 element_instance_key: 2,
                 flow_scope_key: 1,
                 state: :element_activating,
                 element_name: "Start Event",
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_1",
                 element_instance_key: 2,
                 flow_scope_key: 1,
                 state: :element_activated,
                 element_name: "Start Event",
                 element_type: :start_event
               }
               | _audit_log_tail
             ] = audit_log
    end
  end

  describe "start w/ trip_process" do
    setup do
      definition =
        [id: "trip_flow", name: "Trip Flow"]
        |> ProcessDefinition.new()
        |> ProcessDefinition.add_event(%{id: "start_event_42", type: :start_event})
        |> ProcessDefinition.add_activity(%{id: "activity_1", type: :user_task, name: "Book flight"})
        |> ProcessDefinition.add_sequence_flow(%{
          id: "flow_1",
          source_ref: "start_event_42",
          target_ref: "activity_1"
        })

      %{definition: definition}
    end

    test "should return expected workflow audit log", %{definition: definition} do
      audit_log =
        InMemoryEngine.new()
        |> InMemoryEngine.run(EngineAlgebra.create_instance(definition: definition))
        |> InMemoryEngine.audit_log()

      assert [
               %{
                 element_id: "trip_flow",
                 element_instance_key: 1,
                 flow_scope_key: :none,
                 state: :element_activating,
                 element_name: :undefined,
                 element_type: :process
               },
               %{
                 element_id: "trip_flow",
                 element_instance_key: 1,
                 flow_scope_key: :none,
                 state: :element_activated,
                 element_name: :undefined,
                 element_type: :process
               },
               %{
                 state: :element_activating,
                 element_id: "start_event_42",
                 element_instance_key: 2,
                 flow_scope_key: 1,
                 element_name: :undefined,
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_42",
                 element_instance_key: 2,
                 flow_scope_key: 1,
                 state: :element_activated,
                 element_name: :undefined,
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_42",
                 element_instance_key: 2,
                 flow_scope_key: 1,
                 state: :element_completing,
                 element_name: :undefined,
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_42",
                 element_instance_key: 2,
                 flow_scope_key: 1,
                 state: :element_completed,
                 element_name: :undefined,
                 element_type: :start_event
               }
               | _audit_log_tail
             ] = audit_log
    end
  end
end
