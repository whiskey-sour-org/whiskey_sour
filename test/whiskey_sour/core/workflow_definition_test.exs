defmodule WhiskeySour.Core.WorkflowDefinitionTest do
  use ExUnit.Case, async: true

  alias WhiskeySour.Core.WorkflowDefinition

  doctest WhiskeySour.Core.WorkflowDefinition

  describe "new/2" do
    test "creates a new workflow definition with given id and name" do
      id = "order_process"
      name = "Order Processing"
      workflow = WorkflowDefinition.new(id, name)

      assert %{
               id: ^id,
               name: ^name,
               activities: [],
               events: [],
               gateways: [],
               sequence_flows: []
             } = workflow
    end
  end

  describe "add_activity/2" do
    test "adds an activity to the workflow definition" do
      workflow = WorkflowDefinition.new("order_process", "Order Processing")
      activity = %{id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"}
      updated_workflow = WorkflowDefinition.add_activity(workflow, activity)

      assert updated_workflow.activities == [activity]
    end
  end

  describe "add_event/2" do
    test "adds an event to the workflow definition" do
      workflow = WorkflowDefinition.new("order_process", "Order Processing")
      event = %{id: "start_event", type: :start_event, name: "Start Event"}
      updated_workflow = WorkflowDefinition.add_event(workflow, event)

      assert updated_workflow.events == [event]
    end
  end

  describe "add_gateway/2" do
    test "adds a gateway to the workflow definition" do
      workflow = WorkflowDefinition.new("order_process", "Order Processing")
      gateway = %{id: "decision_gateway", type: :exclusive, name: "Decision Gateway"}
      updated_workflow = WorkflowDefinition.add_gateway(workflow, gateway)

      assert updated_workflow.gateways == [gateway]
    end
  end

  describe "add_sequence_flow/2" do
    test "adds a sequence flow to the workflow definition" do
      workflow = WorkflowDefinition.new("order_process", "Order Processing")
      sequence_flow = %{id: "flow1", source_ref: "start_event", target_ref: "review_order"}
      updated_workflow = WorkflowDefinition.add_sequence_flow(workflow, sequence_flow)

      assert updated_workflow.sequence_flows == [sequence_flow]
    end
  end
end
