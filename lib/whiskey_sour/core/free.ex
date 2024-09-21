defmodule WhiskeySour.Core.Free do
  @moduledoc """
  Represents the Free monad.
  """
  defstruct [:functor, :value]

  @type t :: %__MODULE__{
          functor: any(),
          value: any()
        }

  @spec return(any()) :: t()
  def return(value), do: %__MODULE__{functor: nil, value: value}

  @spec lift(any()) :: t()
  def lift(fa), do: %__MODULE__{functor: fa, value: nil}

  @spec bind(t(), (any() -> t())) :: t()
  def bind(free, f) do
    %__MODULE__{functor: {:bind, free, f}, value: nil}
  end
end
