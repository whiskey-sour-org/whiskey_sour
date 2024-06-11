defmodule WhiskeySour.Core.ProcessInstance do
  @moduledoc """
  The `WhiskeySour.Core.ProcessInstance` module represents an instance of a BPMN workflow process.

  A process instance is a specific execution of a workflow definition. It tracks the state of the process, including the current tokens and the associated workflow definition.

  ## Attributes

  - `tokens`: A list of tokens that represent the current state and progress of the process instance.
  - `definition`: The workflow definition that this process instance is executing.
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
  Represents an event in the process definition.
  """
  @type event :: %{
          id: String.t(),
          node_id: String.t(),
          status: :completed | :terminated
        }

  @typedoc """
  Represents a process instance.
  """
  @type process_instance :: %{
          id: String.t(),
          tokens: [token()],
          definition: ProcessDefinition.t(),
          uncommitted_events: [event()],
          committed_events: [event()]
        }
  @type t :: process_instance()

  @enforce_keys [:tokens, :definition, :uncommitted_events, :committed_events]
  defstruct [:tokens, :definition, :uncommitted_events, :committed_events]

  @doc """
  Creates a new process instance for the given workflow definition.

  ## Parameters

  - `definition`: The workflow definition to be executed by this process instance.

  ## Returns

  A new process instance struct.
  """
  @spec construct(ProcessDefinition.t()) :: t()
  def construct(definition) when is_map(definition) do
    %__MODULE__{
      tokens: [],
      definition: definition,
      uncommitted_events: [],
      committed_events: []
    }
  end

  def start(%{uncommitted_events: [], committed_events: []} = process_instance) do
    start_event_definition = Enum.find(process_instance.definition.events, &(&1.type == :start_event))

    uncommitted_events = [
      %{
        id: "evt:#{start_event_definition.id}:1",
        node_id: start_event_definition.id,
        status: :completed
      }
    ]

    # find the node after the start event
    token_node_id =
      Enum.find(process_instance.definition.sequence_flows, &(&1.source_ref == start_event_definition.id)).target_ref

    token = %{
      node_id: token_node_id,
      status: :active,
      id: "token:1"
    }

    %{process_instance | uncommitted_events: uncommitted_events, tokens: [token]}
  end
end
