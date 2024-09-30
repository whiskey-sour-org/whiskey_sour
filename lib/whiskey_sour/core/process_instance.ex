defmodule WhiskeySour.Core.ProcessInstance do
  @moduledoc false
  defstruct ~w(key process_definition_id process_key state)a

  def new(opts) do
    valid_opts = Keyword.validate!(opts, [:key, :process_key, :process_key, :process_definition_id, :state])
    key = Keyword.fetch!(valid_opts, :key)
    process_key = Keyword.fetch!(valid_opts, :process_key)
    process_definition_id = Keyword.fetch!(valid_opts, :process_definition_id)
    state = Keyword.fetch!(valid_opts, :state)

    %__MODULE__{
      key: key,
      process_definition_id: process_definition_id,
      process_key: process_key,
      state: state
    }
  end
end
