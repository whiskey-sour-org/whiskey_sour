defmodule WhiskeySour.Core.Engine.EngineFunctor do
  @moduledoc """
  Defines the `EngineFunctor`, which encapsulates individual operations that the workflow engine can perform.

  ## Operations

  - `:deploy_definition`: Deploys a new process definition.
  - `:create_instance`: Creates a new instance of a deployed process.
  - `:activate_process`: Activates a process instance.
  - `:activate_start_event`: Activates the start event of a process.
  - `:take_next_flow`: Takes the next sequence flow in the process.
  - `:activate_element`: Activates a specific element within the process.
  - `:subscribe`: Subscribes to specific engine events.
  - Additional operations can be added as needed.
  """
  defstruct [:operation, :args]

  @type t :: %__MODULE__{
          operation: atom(),
          args: map()
        }

  @spec new(atom(), keyword()) :: t()
  def new(operation, args \\ []), do: %__MODULE__{operation: operation, args: args}
end
