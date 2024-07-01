defmodule WhiskeySour.Core.ProcessInstance do
  @moduledoc """
  The `WhiskeySour.Core.ProcessInstance` module represents an instance of a BPMN workflow process.

  A process instance is a specific execution of a workflow definition. It tracks the state of the process, including the current tokens and the associated workflow definition.

  ## Attributes

  - `tokens`: A list of tokens that represent the current state and progress of the process instance.
  - `definition`: The workflow definition that this process instance is executing.
  """

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
