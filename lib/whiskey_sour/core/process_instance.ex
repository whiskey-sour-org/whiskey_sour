defmodule WhiskeySour.Core.ProcessInstance.ProcessFunctor do
  # The Functor representing process operations
  @moduledoc false
  defstruct [:operation, :args]

  def new(operation, args \\ []) do
    %__MODULE__{operation: operation, args: args}
  end
end

defmodule WhiskeySour.Core.ProcessInstance do
  @moduledoc """
  The `WhiskeySour.Core.ProcessInstance` module represents an instance of a BPMN workflow process.

  A process instance is a specific execution of a workflow definition. It tracks the state of the process, including the current tokens and the associated workflow definition.

  ## Attributes

  - `tokens`: A list of tokens that represent the current state and progress of the process instance.
  - `definition`: The workflow definition that this process instance is executing.
  """

  alias WhiskeySour.Core.ProcessDefinition
  alias WhiskeySour.Core.ProcessInstance.ProcessFunctor

  defmodule Free do
    @moduledoc false
    defstruct [:functor, :value]

    def return(value), do: %Free{functor: nil, value: value}

    def lift(fa), do: %Free{functor: fa, value: nil}

    def bind(free, f) do
      %Free{functor: {:bind, free, f}, value: nil}
    end
  end

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

  @enforce_keys [:key, :definition]
  defstruct [:key, :definition]

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
      :key
    ])
    |> then(&struct!(__MODULE__, &1))
  end

  # Lifting process operations into the free monad
  def activate_process(name), do: Free.lift(ProcessFunctor.new(:activate_process, [name]))

  def activate_start_event(args), do: Free.lift(ProcessFunctor.new(:activate_start_event, args))

  def start(opts) do
    definition = Keyword.fetch!(opts, :definition)

    Free.bind(activate_process(definition.id), fn process_id ->
      start_event = Enum.find(definition.events, &(&1.type == :start_event))
      start_event_id = start_event.id
      start_event_name = Map.get(start_event, :name, :undefined)

      Free.bind(
        activate_start_event(
          process_id: process_id,
          element_id: start_event_id,
          element_name: start_event_name
        ),
        fn _event_id ->
          Free.return(:ok)
        end
      )
    end)
  end
end
