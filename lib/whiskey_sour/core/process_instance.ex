defmodule WhiskeySour.Core.ProcessInstance do
  @moduledoc """
  The `WhiskeySour.Core.ProcessInstance` module represents an instance of a BPMN workflow process.

  A process instance is a specific execution of a workflow definition. It tracks the state of the process, including the current tokens and the associated workflow definition.

  ## Attributes

  - `tokens`: A list of tokens that represent the current state and progress of the process instance.
  - `definition`: The workflow definition that this process instance is executing.

  ## Example

      iex> definition = ProcessDefinition.new("order_process", "Order Processing")
      iex> |> ProcessDefinition.add_event(%{id: "start_event", type: :start_event, name: "Start Event"})
      iex> |> ProcessDefinition.add_activity(%{id: "review_order", type: :user_task, name: "Review Order", assignee: "user1"})
      iex> |> ProcessDefinition.add_event(%{id: "end_event", type: :end_event, name: "End Event"})
      iex> |> ProcessDefinition.add_sequence_flow(%{id: "flow1", source_ref: "start_event", target_ref: "review_order"})
      iex> |> ProcessDefinition.add_sequence_flow(%{id: "flow2", source_ref: "review_order", target_ref: "end_event"})
      iex> ProcessInstance.construct(definition)
      %ProcessInstance{
        tokens: [],
        definition: definition
      }

  """

  alias WhiskeySour.Core.ProcessDefinition

  @typedoc """
  Represents a token in the process instance.
  """
  @type token :: %{
          id: String.t(),
          node_id: String.t(),
          status: :active | :completed | :terminated
        }

  @typedoc """
  Represents a process instance.
  """
  @type process_instance :: %{
          id: String.t(),
          tokens: [token()],
          definition: ProcessDefinition.t()
        }
  @type t :: process_instance()

  @enforce_keys [:tokens, :definition]
  defstruct ~w(tokens definition)a

  @doc """
  Creates a new process instance for the given workflow definition.

  ## Parameters

  - `definition`: The workflow definition to be executed by this process instance.

  ## Returns

  A new process instance struct.

  ## Example

      iex> definition = %{
      ...>   id: "order_process",
      ...>   name: "Order Processing",
      ...>   activities: [],
      ...>   events: [],
      ...>   gateways: [],
      ...>   sequence_flows: []
      ...> }
      iex> ProcessInstance.construct(definition)
      %ProcessInstance{
        tokens: [],
        definition: definition
      }
  """
  @spec construct(ProcessDefinition.t()) :: t()
  def construct(definition) when is_map(definition) do
    %__MODULE__{
      tokens: [],
      definition: definition
    }
  end
end
