defmodule WhiskeySour.Core.ProcessInstance do
  @moduledoc false
  defstruct ~w(key bpmn_process_id process_key state)a

  def new(opts) do
    valid_opts = Keyword.validate!(opts, [:key, :process_key, :process_key, :bpmn_process_id, :state])
    key = Keyword.fetch!(valid_opts, :key)
    process_key = Keyword.fetch!(valid_opts, :process_key)
    bpmn_process_id = Keyword.fetch!(valid_opts, :bpmn_process_id)
    state = Keyword.fetch!(valid_opts, :state)

    %__MODULE__{
      key: key,
      bpmn_process_id: bpmn_process_id,
      process_key: process_key,
      state: state
    }
  end
end
