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
        |> ProcessDefinition.add_event(id: "start_event_1", type: :start_event, name: "Start Event")
        |> ProcessDefinition.add_activity(id: "review_order", type: :user_task, name: "Review Order", assignee: "user1")
        |> ProcessDefinition.add_event(id: "end_event_1", type: :end_event, name: "End Event")
        |> ProcessDefinition.add_sequence_flow(id: "flow1", source_ref: "start_event_1", target_ref: "review_order")
        |> ProcessDefinition.add_sequence_flow(id: "flow2", source_ref: "review_order", target_ref: "end_event_1")

      %{definition: definition}
    end

    test "should publish `process_deployed` event", %{definition: definition} do
      correlation_ref = make_ref()

      _engine =
        Enum.into(
          [
            EngineAlgebra.subscribe(to: :process_deployed, event_handler: &send(self(), &1)),
            EngineAlgebra.deploy_definition(definition: definition, correlation_ref: correlation_ref)
          ],
          InMemoryEngine.new()
        )

      assert_received %{
        event_name: :process_deployed,
        event_payload: %{
          key: _key,
          workflows: [
            %{
              bpmn_process_id: "order_process",
              version: 1,
              process_key: _process_key
            }
          ]
        },
        correlation_ref: ^correlation_ref
      }
    end

    test "should update `process_definitions_stream`", %{definition: definition} do
      engine =
        Enum.into(
          [
            EngineAlgebra.deploy_definition(definition: definition)
          ],
          InMemoryEngine.new()
        )

      assert [
               %{
                 process_key: _process_key,
                 name: "Order Processing",
                 version: 1,
                 bpmn_process_id: "order_process"
               }
             ] = engine |> InMemoryEngine.process_definitions_stream() |> Enum.to_list()
    end
  end

  describe "create_instance w/ order_process" do
    setup do
      definition =
        [id: "order_process", name: "Order Processing"]
        |> ProcessDefinition.new()
        |> ProcessDefinition.add_event(id: "start_event_1", type: :start_event, name: "Start Event")
        |> ProcessDefinition.add_activity(id: "review_order", type: :user_task, name: "Review Order", assignee: "user1")
        |> ProcessDefinition.add_event(id: "end_event_1", type: :end_event, name: "End Event")
        |> ProcessDefinition.add_sequence_flow(id: "flow1", source_ref: "start_event_1", target_ref: "review_order")
        |> ProcessDefinition.add_sequence_flow(id: "flow2", source_ref: "review_order", target_ref: "end_event_1")

      %{definition: definition}
    end

    test "should return expected workflow audit log", %{definition: definition} do
      engine =
        Enum.into(
          [
            EngineAlgebra.deploy_definition(definition: definition),
            EngineAlgebra.create_instance(bpmn_process_id: definition.id)
          ],
          InMemoryEngine.new()
        )

      assert [
               %{
                 element_id: "order_process",
                 element_instance_key: order_process_element_instance_key,
                 flow_scope_key: :none,
                 state: :element_activating,
                 element_name: :undefined,
                 element_type: :process
               },
               %{
                 element_id: "order_process",
                 element_instance_key: order_process_element_instance_key,
                 flow_scope_key: :none,
                 state: :element_activated,
                 element_name: :undefined,
                 element_type: :process
               },
               %{
                 element_id: "start_event_1",
                 element_instance_key: start_event_1_element_instance_key,
                 flow_scope_key: flow_scope_key,
                 state: :element_activating,
                 element_name: "Start Event",
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_1",
                 element_instance_key: start_event_1_element_instance_key,
                 flow_scope_key: flow_scope_key,
                 state: :element_activated,
                 element_name: "Start Event",
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_1",
                 element_instance_key: start_event_1_element_instance_key,
                 flow_scope_key: flow_scope_key,
                 state: :element_completing,
                 element_name: "Start Event",
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_1",
                 element_instance_key: start_event_1_element_instance_key,
                 flow_scope_key: flow_scope_key,
                 state: :element_completed,
                 element_name: "Start Event",
                 element_type: :start_event
               },
               %{
                 element_id: "flow1",
                 element_instance_key: _flow1_element_instance_key,
                 flow_scope_key: flow_scope_key,
                 state: :element_taken,
                 element_type: :sequence_flow
               },
               %{
                 element_id: "review_order",
                 element_instance_key: review_order_element_instance_key,
                 flow_scope_key: flow_scope_key,
                 state: :element_activating,
                 element_name: "Review Order",
                 element_type: :user_task
               },
               %{
                 element_id: "review_order",
                 element_instance_key: review_order_element_instance_key,
                 flow_scope_key: flow_scope_key,
                 state: :element_activated,
                 element_name: "Review Order",
                 element_type: :user_task
               }
             ] = InMemoryEngine.audit_log(engine)
    end

    test "should create review_order user_task", %{definition: definition} do
      correlation_ref = make_ref()

      engine =
        Enum.into(
          [
            EngineAlgebra.deploy_definition(definition: definition),
            EngineAlgebra.subscribe(to: :process_activated, event_handler: &send(self(), &1)),
            EngineAlgebra.create_instance(bpmn_process_id: definition.id, correlation_ref: correlation_ref)
          ],
          InMemoryEngine.new()
        )

      assert_received %{
        event_name: :process_activated,
        event_payload: %{
          process_instance_key: process_instance_key
        },
        correlation_ref: ^correlation_ref
      }

      assert [
               %{
                 assignee: "user1",
                 candidate_groups: [],
                 element_id: "review_order",
                 element_instance_key: _,
                 name: "Review Order",
                 process_instance_key: ^process_instance_key,
                 state: :active
               }
             ] = engine |> InMemoryEngine.user_tasks_stream() |> Enum.to_list()
    end
  end

  describe "start w/ trip_process" do
    setup do
      definition =
        [id: "trip_flow", name: "Trip Flow"]
        |> ProcessDefinition.new()
        |> ProcessDefinition.add_event(id: "start_event_42", type: :start_event)
        |> ProcessDefinition.add_activity(id: "activity_1", type: :user_task, name: "Book flight")
        |> ProcessDefinition.add_sequence_flow(
          id: "flow_1",
          source_ref: "start_event_42",
          target_ref: "activity_1"
        )

      %{definition: definition}
    end

    test "should return expected workflow audit log", %{definition: definition} do
      engine =
        Enum.into(
          [
            EngineAlgebra.deploy_definition(definition: definition),
            EngineAlgebra.create_instance(bpmn_process_id: definition.id)
          ],
          InMemoryEngine.new()
        )

      assert [
               %{
                 element_id: "trip_flow",
                 element_instance_key: key_1,
                 flow_scope_key: :none,
                 state: :element_activating,
                 element_name: :undefined,
                 element_type: :process
               },
               %{
                 element_id: "trip_flow",
                 element_instance_key: key_1,
                 flow_scope_key: :none,
                 state: :element_activated,
                 element_name: :undefined,
                 element_type: :process
               },
               %{
                 state: :element_activating,
                 element_id: "start_event_42",
                 element_instance_key: key_2,
                 flow_scope_key: flow_scope_key_1,
                 element_name: :undefined,
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_42",
                 element_instance_key: key_2,
                 flow_scope_key: flow_scope_key_1,
                 state: :element_activated,
                 element_name: :undefined,
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_42",
                 element_instance_key: key_2,
                 flow_scope_key: flow_scope_key_1,
                 state: :element_completing,
                 element_name: :undefined,
                 element_type: :start_event
               },
               %{
                 element_id: "start_event_42",
                 element_instance_key: key_2,
                 flow_scope_key: flow_scope_key_1,
                 state: :element_completed,
                 element_name: :undefined,
                 element_type: :start_event
               },
               %{
                 element_id: "flow_1",
                 element_instance_key: _key_3,
                 flow_scope_key: flow_scope_key_1,
                 state: :element_taken,
                 element_type: :sequence_flow
               },
               %{
                 element_id: "activity_1",
                 element_instance_key: key_4,
                 flow_scope_key: flow_scope_key_1,
                 state: :element_activating,
                 element_name: "Book flight",
                 element_type: :user_task
               },
               %{
                 element_id: "activity_1",
                 element_instance_key: key_4,
                 flow_scope_key: flow_scope_key_1,
                 state: :element_activated,
                 element_name: "Book flight",
                 element_type: :user_task
               }
             ] = InMemoryEngine.audit_log(engine)
    end

    test "should create Book flight user_task", %{definition: definition} do
      correlation_ref = make_ref()

      engine =
        Enum.into(
          [
            EngineAlgebra.deploy_definition(definition: definition),
            EngineAlgebra.subscribe(to: :process_activated, event_handler: &send(self(), &1)),
            EngineAlgebra.create_instance(bpmn_process_id: definition.id, correlation_ref: correlation_ref)
          ],
          InMemoryEngine.new()
        )

      assert_received %{
        event_name: :process_activated,
        event_payload: %{
          process_instance_key: process_instance_key
        },
        correlation_ref: ^correlation_ref
      }

      assert [
               %{
                 assignee: :unassigned,
                 candidate_groups: [],
                 element_id: "activity_1",
                 element_instance_key: _key,
                 name: "Book flight",
                 process_instance_key: ^process_instance_key,
                 state: :active
               }
             ] = engine |> InMemoryEngine.user_tasks_stream() |> Enum.to_list()
    end
  end
end
