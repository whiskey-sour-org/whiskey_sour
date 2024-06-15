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
  Represents an uncommitted event in the process instance.
  """
  @type uncommitted_event :: %{
          element_id: String.t(),
          element_instance_key: String.t(),
          flow_scope_key: :none | String.t(),
          state: :element_activating | :element_activated | :element_completing | :element_completed,
          element_name: String.t() | :undefined,
          element_type: :process | :start_event | :end_event | :task | :gateway | :sequence_flow
        }

  @typedoc """
  Represents an committed event in the process instance.
  """
  @type event :: %{
          element_id: String.t(),
          element_instance_key: String.t(),
          flow_scope_key: :none | String.t(),
          state: :element_activating | :element_activated | :element_completing | :element_completed,
          element_name: String.t() | :undefined,
          element_type: :process | :start_event | :end_event | :task | :gateway | :sequence_flow,
          timestamp: DateTime.t()
        }

  @type process_instance_key :: pos_integer()
  @typedoc """
  Represents a process instance.
  """
  @type process_instance :: %{
          key: process_instance_key(),
          definition: ProcessDefinition.t(),
          uncommitted_events: [uncommitted_event()],
          committed_events: [event()]
        }
  @type t :: process_instance()

  @enforce_keys [:key, :definition, :uncommitted_events, :committed_events]
  defstruct [:key, :definition, :uncommitted_events, :committed_events]

  @doc """
  Creates a new process instance for the given workflow definition.

  ## Parameters

  - `definition`: The workflow definition to be executed by this process instance.

  ## Returns

  A new process instance struct.
  """
  @type construct_opts ::
          keyword(
            definition: ProcessDefinition.t(),
            key: process_instance_key()
          )
  @spec construct(construct_opts()) :: t()
  def construct(opts) when is_list(opts) do
    opts
    |> Keyword.validate!([
      :definition,
      :key,
      uncommitted_events: [],
      committed_events: []
    ])
    |> then(&struct!(__MODULE__, &1))
  end

  def start(%{uncommitted_events: [], committed_events: []} = process_instance) do
    start_event_definition =
      Enum.find(
        process_instance.definition.events,
        fn ->
          raise "No start event found in process definition"
        end,
        &(&1.type == :start_event)
      )

    process_element_id = process_instance.definition.id

    uncommitted_events = [
      %{
        element_id: process_element_id,
        element_instance_key: process_instance.key,
        flow_scope_key: :none,
        state: :element_activating,
        element_name: :undefined,
        element_type: :process
      },
      %{
        element_id: process_element_id,
        element_instance_key: process_instance.key,
        flow_scope_key: :none,
        state: :element_activated,
        element_name: :undefined,
        element_type: :process
      },
      %{
        element_id: Map.fetch!(start_event_definition, :id),
        element_instance_key: :todo,
        flow_scope_key: process_instance.key,
        state: :element_activating,
        element_name: Map.get(start_event_definition, :name, :undefined),
        element_type: :start_event
      }
    ]

    %{process_instance | uncommitted_events: uncommitted_events}
  end
end
