defmodule WhiskeySour.Core.ProcessDefinitionTest do
  use ExUnit.Case, async: true

  alias WhiskeySour.Core.ProcessDefinition

  doctest WhiskeySour.Core.ProcessDefinition

  describe "new/2" do
    test "creates a new process definition with given id and name" do
      id = "order_process"
      name = "Order Processing"
      process = ProcessDefinition.new(id: id, name: name)

      assert %{
               id: ^id,
               name: ^name,
               activities: [],
               events: [],
               gateways: [],
               sequence_flows: []
             } = process
    end
  end

  describe "add_activity/2" do
    test "adds an activity to the process definition" do
      process = ProcessDefinition.new(id: "order_process", name: "Order Processing")
      activity = [id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"]
      updated_process = ProcessDefinition.add_activity(process, activity)

      assert updated_process.activities == [
               %{
                 id: "review_order",
                 type: :user_task,
                 name: "Review Order",
                 assignee: "user1"
               }
             ]
    end
  end

  describe "add_event/2" do
    test "adds an event to the process definition" do
      process = ProcessDefinition.new(id: "order_process", name: "Order Processing")
      event = [id: "start_event", type: :start_event, name: "Start Event"]
      updated_process = ProcessDefinition.add_event(process, event)

      assert updated_process.events == [
               %{
                 id: "start_event",
                 type: :start_event,
                 name: "Start Event"
               }
             ]
    end
  end

  describe "add_gateway/2" do
    test "adds a gateway to the process definition" do
      process = ProcessDefinition.new(id: "order_process", name: "Order Processing")
      gateway = [id: "decision_gateway", type: :exclusive, name: "Decision Gateway"]
      updated_process = ProcessDefinition.add_gateway(process, gateway)

      assert updated_process.gateways == [
               %{
                 id: "decision_gateway",
                 type: :exclusive,
                 name: "Decision Gateway"
               }
             ]
    end
  end

  describe "add_sequence_flow/2" do
    test "adds a sequence flow to the process definition" do
      process = ProcessDefinition.new(id: "order_process", name: "Order Processing")
      sequence_flow = [id: "flow1", source_ref: "start_event", target_ref: "review_order"]
      updated_process = ProcessDefinition.add_sequence_flow(process, sequence_flow)

      assert updated_process.sequence_flows == [
               %{
                 id: "flow1",
                 source_ref: "start_event",
                 target_ref: "review_order"
               }
             ]
    end
  end
end
