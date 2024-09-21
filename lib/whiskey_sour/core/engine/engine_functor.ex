defmodule WhiskeySour.Core.Engine.EngineFunctor do
  @moduledoc """
  Represents the functor for engine operations.
  """
  defstruct [:operation, :args]

  @type t :: %__MODULE__{
          operation: atom(),
          args: map()
        }

  @spec new(atom(), keyword()) :: t()
  def new(operation, args \\ []), do: %__MODULE__{operation: operation, args: args}
end
