defmodule WhiskeySour.Core.Free do
  @moduledoc false
  defstruct [:functor, :value]

  def return(value), do: %__MODULE__{functor: nil, value: value}

  def lift(fa), do: %__MODULE__{functor: fa, value: nil}

  def bind(free, f) do
    %__MODULE__{functor: {:bind, free, f}, value: nil}
  end
end
