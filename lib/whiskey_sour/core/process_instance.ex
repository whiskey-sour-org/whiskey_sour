defmodule WhiskeySour.Core.ProcessInstance do
  @moduledoc false
  defstruct ~w(key bpmn_process_id bpmn_process_key state)a

  def new(opts) do
    key = Keyword.fetch!(opts, :key)
    bpmn_process_key = Keyword.fetch!(opts, :bpmn_process_key)
    bpmn_process_id = Keyword.fetch!(opts, :bpmn_process_id)
    state = Keyword.fetch!(opts, :state)

    %__MODULE__{
      key: key,
      bpmn_process_id: bpmn_process_id,
      bpmn_process_key: bpmn_process_key,
      state: state
    }
  end
end
