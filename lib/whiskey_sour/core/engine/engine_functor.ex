defmodule WhiskeySour.Core.Engine.EngineFunctor do
  @moduledoc """
  Represents the functor for engine operations.
  """
  defstruct [:operation, :args]

  def new(operation, args \\ []), do: %__MODULE__{operation: operation, args: args}
end
