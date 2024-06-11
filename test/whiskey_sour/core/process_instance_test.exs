defmodule WhiskeySour.Core.ProcessInstanceTest do
  use ExUnit.Case

  alias WhiskeySour.Core.ProcessDefinition
  alias WhiskeySour.Core.ProcessInstance

  doctest WhiskeySour.Core.ProcessInstance

  describe "construct/1" do
    test "creates a new process instance for the given workflow definition" do
      definition = sample_order_process_definition()

      process_instance = ProcessInstance.construct(definition)

      assert %{
               tokens: [],
               definition: ^definition
             } = process_instance
    end
  end

  describe "start/1" do
    test "starts the sample_order_process_definition instance" do
      process_instance =
        ProcessInstance.construct(sample_order_process_definition())

      process_instance = ProcessInstance.start(process_instance)

      assert process_instance.uncommitted_events == [
               %{
                 id: "evt:start_event:1",
                 node_id: "start_event",
                 status: :completed
               }
             ]

      assert process_instance.tokens == [
               %{
                 id: "token:1",
                 node_id: "review_order",
                 status: :active
               }
             ]
    end
  end

  describe "jobs/1" do
    test "returns the jobs for the process instance" do
      process_instance =
        sample_order_process_definition()
        |> ProcessInstance.construct()
        |> ProcessInstance.start()

      jobs = ProcessInstance.jobs(process_instance)

      assert jobs == [
               %{
                 node_id: "review_order",
                 assignee: "user1",
                 token_id: "token:1"
               }
             ]
    end
  end

  describe "complete_job/2" do
    test "completes the job for the given token" do
      definition = sample_order_process_definition()
      process_instance = ProcessInstance.construct(definition)
      process_instance = ProcessInstance.start(process_instance)

      process_instance = ProcessInstance.complete_job(process_instance, "token:1")

      assert process_instance.uncommitted_events == [
               %{id: "evt:start_event:1", node_id: "start_event", status: :completed},
               %{id: "evt:review_order:1", node_id: "review_order", status: :completed},
               %{id: "evt:end_event:1", node_id: "end_event", status: :completed}
             ]

      assert process_instance.tokens == [
               %{
                 id: "token:1",
                 node_id: "end_event",
                 status: :terminated
               }
             ]
    end
  end

  def sample_order_process_definition do
    "order_process"
    |> ProcessDefinition.new("Order Processing")
    |> ProcessDefinition.add_event(%{id: "start_event", type: :start_event, name: "Start Event"})
    |> ProcessDefinition.add_activity(%{id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"})
    |> ProcessDefinition.add_event(%{id: "end_event", type: :end_event, name: "End Event"})
    |> ProcessDefinition.add_sequence_flow(%{id: "flow1", source_ref: "start_event", target_ref: "review_order"})
    |> ProcessDefinition.add_sequence_flow(%{id: "flow2", source_ref: "review_order", target_ref: "end_event"})
  end
end
