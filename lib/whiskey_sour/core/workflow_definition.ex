defmodule WhiskeySour.Core.WorkflowDefinition do
  @moduledoc """
  The `WorkflowDefinition` module provides functionality for defining and managing BPMN workflow definitions.

  A Workflow Definition specifies the sequence of activities, events, gateways, and other elements that define how a particular business process is to be executed within an organization.

  ## Components of a Workflow Definition

  - **Activities**: Tasks or work items, such as user tasks, service tasks, and script tasks.
  - **Events**: Occurrences that affect the flow, such as start events, end events, and intermediate events.
  - **Gateways**: Elements that control the flow, including exclusive, parallel, and inclusive gateways.
  - **Sequence Flows**: Connectors that define the order of execution.
  - **Artifacts**: Additional elements like annotations and data objects.
  - **Participants**: Pools and lanes representing organizations or roles.
  - **Data Flow**: Information movement within the process.

  ## Example

  A simple order processing workflow might include:
  - A start event when an order is received.
  - A user task for reviewing the order.
  - An exclusive gateway for decision-making (approve/reject).
  - Service tasks for handling approved orders and notifying customers about rejected orders.
  - End events marking the completion of the process.

  ## Functions

  This module provides functions to create and manage workflow definitions.

  """

  @typedoc """
  Represents an activity in the workflow.
  """
  @type activity :: %{
          id: String.t(),
          type: :user_task | :service_task | :script_task,
          name: String.t(),
          assignee: String.t()
        }

  @typedoc """
  Represents an event in the workflow.
  """
  @type event :: %{
          id: String.t(),
          type: :start_event | :end_event | :intermediate_event,
          name: String.t()
        }

  @typedoc """
  Represents a gateway in the workflow.
  """
  @type gateway :: %{
          id: String.t(),
          type: :exclusive | :parallel | :inclusive,
          name: String.t()
        }

  @typedoc """
  Represents a sequence flow in the workflow.
  """
  @type sequence_flow :: %{
          id: String.t(),
          source_ref: String.t(),
          target_ref: String.t()
        }

  @typedoc """
  Represents a workflow definition.
  """
  @type workflow_definition :: %{
          id: String.t(),
          name: String.t(),
          activities: [activity()],
          events: [event()],
          gateways: [gateway()],
          sequence_flows: [sequence_flow()]
        }

  @doc """
  Creates a new workflow definition.

  ## Parameters

  - `id`: The unique identifier for the workflow.
  - `name`: The name of the workflow.

  ## Returns

  A new workflow definition struct.

  ## Example

      iex> WorkflowDefinition.new("order_process", "Order Processing")
      %{
        id: "order_process",
        name: "Order Processing",
        activities: [],
        events: [],
        gateways: [],
        sequence_flows: []
      }
  """
  def new(id, name) do
    %{
      id: id,
      name: name,
      activities: [],
      events: [],
      gateways: [],
      sequence_flows: []
    }
  end

  @doc """
  Adds an activity to the workflow definition.

  ## Parameters

  - `workflow`: The workflow definition.
  - `activity`: The activity to add.

  ## Returns

  The updated workflow definition.

  ## Example
      iex> workflow = WorkflowDefinition.new("order_process", "Order Processing")
      iex> activity = %{id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"}
      iex> WorkflowDefinition.add_activity(workflow, activity)
      %{
        id: "order_process",
        name: "Order Processing",
        activities: [%{id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"}],
        events: [],
        gateways: [],
        sequence_flows: []
      }
  """
  def add_activity(workflow, activity) do
    update_in(workflow[:activities], &[activity | &1])
  end

  @doc """
  Adds an event to the workflow definition.

  ## Parameters

  - `workflow`: The workflow definition.
  - `event`: The event to add.

  ## Returns

  The updated workflow definition.

  ## Example
      iex> workflow = WorkflowDefinition.new("order_process", "Order Processing")
      iex> event = %{id: "start_event", type: :start_event, name: "Start Event"}
      iex> WorkflowDefinition.add_event(workflow, event)
      %{
        id: "order_process",
        name: "Order Processing",
        activities: [],
        events: [%{id: "start_event", type: :start_event, name: "Start Event"}],
        gateways: [],
        sequence_flows: []
      }
  """
  def add_event(workflow, event) do
    update_in(workflow[:events], &[event | &1])
  end

  @doc """
  Adds a gateway to the workflow definition.

  ## Parameters

  - `workflow`: The workflow definition.
  - `gateway`: The gateway to add.

  ## Returns

  The updated workflow definition.

  ## Example

      iex> workflow = WorkflowDefinition.new("order_process", "Order Processing")
      iex> gateway = %{id: "decision_gateway", type: :exclusive, name: "Decision Gateway"}
      iex> WorkflowDefinition.add_gateway(workflow, gateway)
      %{
        id: "order_process",
        name: "Order Processing",
        activities: [],
        events: [],
        gateways: [%{id: "decision_gateway", type: :exclusive, name: "Decision Gateway"}],
        sequence_flows: []
      }
  """
  def add_gateway(workflow, gateway) do
    update_in(workflow[:gateways], &[gateway | &1])
  end

  @doc """
  Adds a sequence flow to the workflow definition.

  ## Parameters

  - `workflow`: The workflow definition.
  - `sequence_flow`: The sequence flow to add.

  ## Returns

  The updated workflow definition.

  ## Example
      iex> workflow = WorkflowDefinition.new("order_process", "Order Processing")
      iex> |> WorkflowDefinition.add_event(%{id: "start_event", type: :start_event, name: "Start Event"})
      iex> sequence_flow = %{id: "flow1", source_ref: "start_event", target_ref: "review_order"}
      iex> WorkflowDefinition.add_sequence_flow(workflow, sequence_flow)
      %{
        id: "order_process",
        name: "Order Processing",
        activities: [],
        events: [%{id: "start_event", type: :start_event, name: "Start Event"}],
        gateways: [],
        sequence_flows: [%{id: "flow1", source_ref: "start_event", target_ref: "review_order"}]
      }
  """
  def add_sequence_flow(workflow, sequence_flow) do
    update_in(workflow[:sequence_flows], &[sequence_flow | &1])
  end
end
