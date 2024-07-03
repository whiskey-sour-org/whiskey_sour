defmodule WhiskeySour.Core.ProcessDefinition do
  @moduledoc """
  The `ProcessDefinition` module provides functionality for defining and managing BPMN process definitions.

  A Process Definition specifies the sequence of activities, events, gateways, and other elements that define how a particular business process is to be executed within an organization.

  ## Components of a Process Definition

  - **Activities**: Tasks or work items, such as user tasks, service tasks, and script tasks.
  - **Events**: Occurrences that affect the flow, such as start events, end events, and intermediate events.
  - **Gateways**: Elements that control the flow, including exclusive, parallel, and inclusive gateways.
  - **Sequence Flows**: Connectors that define the order of execution.
  - **Artifacts**: Additional elements like annotations and data objects.
  - **Participants**: Pools and lanes representing organizations or roles.
  - **Data Flow**: Information movement within the process.

  ## Example

  A simple order processing process might include:
  - A start event when an order is received.
  - A user task for reviewing the order.
  - An exclusive gateway for decision-making (approve/reject).
  - Service tasks for handling approved orders and notifying customers about rejected orders.
  - End events marking the completion of the process.

  ## Functions

  This module provides functions to create and manage process definitions.

  """

  @typedoc """
  Represents an activity in the process.
  """
  @type activity :: %{
          id: String.t(),
          type: :user_task | :service_task | :script_task,
          name: String.t(),
          assignee: String.t()
        }

  @typedoc """
  Represents an event in the process.
  """
  @type event :: %{
          id: String.t(),
          type: :start_event | :end_event | :intermediate_event,
          name: String.t()
        }

  @typedoc """
  Represents a gateway in the process.
  """
  @type gateway :: %{
          id: String.t(),
          type: :exclusive | :parallel | :inclusive,
          name: String.t()
        }

  @typedoc """
  Represents a sequence flow in the process.
  """
  @type sequence_flow :: %{
          id: String.t(),
          source_ref: String.t(),
          target_ref: String.t()
        }

  @typedoc """
  Represents a process definition.
  """
  @type process_definition :: %{
          id: String.t(),
          name: String.t(),
          activities: [activity()],
          events: [event()],
          gateways: [gateway()],
          sequence_flows: [sequence_flow()]
        }
  @type t :: process_definition()

  @enforce_keys ~w(id name activities events gateways sequence_flows)a
  defstruct ~w(id name activities events gateways sequence_flows)a

  @doc """
  Creates a new process definition.

  ## Parameters

  - `id`: The unique identifier for the process.
  - `name`: The name of the process.

  ## Returns

  A new process definition struct.

  ## Example

      iex> ProcessDefinition.new(id: "order_process", name: "Order Processing")
      %ProcessDefinition{
        id: "order_process",
        name: "Order Processing",
        activities: [],
        events: [],
        gateways: [],
        sequence_flows: []
      }
  """
  def new(values) do
    values
    |> Keyword.validate!([
      :id,
      :name,
      activities: [],
      events: [],
      gateways: [],
      sequence_flows: []
    ])
    |> then(&struct!(__MODULE__, &1))
  end

  @doc """
  Adds an activity to the process definition.

  ## Parameters

  - `process`: The process definition.
  - `activity`: The activity to add.

  ## Returns

  The updated process definition.

  ## Example
      iex> process = ProcessDefinition.new(id: "order_process", name: "Order Processing")
      iex> activity = [id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"]
      iex> ProcessDefinition.add_activity(process, activity)
      %ProcessDefinition{
        id: "order_process",
        name: "Order Processing",
        activities: [%{id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"}],
        events: [],
        gateways: [],
        sequence_flows: []
      }
  """
  def add_activity(process, activity_attrs) do
    activity =
      activity_attrs
      |> Keyword.validate!([:id, :type, :name, :assignee])
      |> Map.new()

    unless activity.type in [:user_task, :service_task, :script_task] do
      raise ArgumentError, "Invalid activity type: #{activity.type}"
    end

    update_in(process, [Access.key!(:activities)], &[activity | &1])
  end

  @doc """
  Adds an event to the process definition.

  ## Parameters

  - `process`: The process definition.
  - `event`: The event to add.

  ## Returns

  The updated process definition.

  ## Example
      iex> process = ProcessDefinition.new(id: "order_process", name: "Order Processing")
      iex> event_attrs = [id: "start_event", type: :start_event, name: "Start Event"]
      iex> ProcessDefinition.add_event(process, event_attrs)
      %ProcessDefinition{
        id: "order_process",
        name: "Order Processing",
        activities: [],
        events: [%{id: "start_event", type: :start_event, name: "Start Event"}],
        gateways: [],
        sequence_flows: []
      }
  """
  def add_event(process, event_attrs) do
    event =
      event_attrs
      |> Keyword.validate!([:id, :type, name: :undefined])
      |> Map.new()

    update_in(process, [Access.key!(:events)], &[event | &1])
  end

  @doc """
  Adds a gateway to the process definition.

  ## Parameters

  - `process`: The process definition.
  - `gateway_attrs`: The gateway attributes to add.

  ## Returns

  The updated process definition.

  ## Example

      iex> process = ProcessDefinition.new(id: "order_process", name: "Order Processing")
      iex> gateway_attrs = [id: "decision_gateway", type: :exclusive, name: "Decision Gateway"]
      iex> ProcessDefinition.add_gateway(process, gateway_attrs)
      %ProcessDefinition{
        id: "order_process",
        name: "Order Processing",
        activities: [],
        events: [],
        gateways: [%{id: "decision_gateway", type: :exclusive, name: "Decision Gateway"}],
        sequence_flows: []
      }
  """
  def add_gateway(process, gateway_attrs) do
    gateway =
      gateway_attrs
      |> Keyword.validate!([:id, :type, name: :undefined])
      |> Map.new()

    unless gateway.type in [:exclusive, :parallel, :inclusive] do
      raise ArgumentError, "Invalid gateway type: #{gateway.type}"
    end

    update_in(process, [Access.key!(:gateways)], &[gateway | &1])
  end

  @doc """
  Adds a sequence flow to the process definition.

  ## Parameters

  - `process`: The process definition.
  - `sequence_flow`: The sequence flow to add.

  ## Returns

  The updated process definition.

  ## Example
      iex> process = ProcessDefinition.new(id: "order_process", name: "Order Processing")
      iex> |> ProcessDefinition.add_event(id: "start_event", type: :start_event, name: "Start Event")
      iex> sequence_flow = [id: "flow1", source_ref: "start_event", target_ref: "review_order"]
      iex> ProcessDefinition.add_sequence_flow(process, sequence_flow)
      %ProcessDefinition{
        id: "order_process",
        name: "Order Processing",
        activities: [],
        events: [%{id: "start_event", type: :start_event, name: "Start Event"}],
        gateways: [],
        sequence_flows: [%{id: "flow1", source_ref: "start_event", target_ref: "review_order"}]
      }
  """
  def add_sequence_flow(process, sequence_flow_attrs) do
    sequence_flow =
      sequence_flow_attrs
      |> Keyword.validate!([:id, :source_ref, :target_ref])
      |> Map.new()

    update_in(process, [Access.key!(:sequence_flows)], &[sequence_flow | &1])
  end

  def fetch_start_event(%__MODULE__{events: events}) do
    case Enum.find(events, &(&1.type == :start_event)) do
      nil -> {:error, :start_event_not_found}
      start_event -> {:ok, start_event}
    end
  end

  def fetch_sequence_flow_by_source_ref(%__MODULE__{sequence_flows: sequence_flows}, source_ref) do
    sequence_flows
    |> Enum.find(&(&1.source_ref == source_ref))
    |> case do
      nil -> {:error, :sequence_flow_not_found}
      sequence_flow -> {:ok, sequence_flow}
    end
  end

  def fetch_element_by_id(%__MODULE__{activities: activities, events: events, gateways: gateways}, id) do
    [activities, events, gateways]
    |> Enum.flat_map(& &1)
    |> Enum.find(&(&1.id == id))
    |> case do
      nil -> {:error, :element_not_found}
      element -> {:ok, element}
    end
  end
end
