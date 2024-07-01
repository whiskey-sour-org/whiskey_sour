defmodule WhiskeySour.Core.Engine.EngineAlgebra do
  @moduledoc false
  alias WhiskeySour.Core.Engine.EngineFunctor
  alias WhiskeySour.Core.Free

  def create_instance(opts) do
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

  def deploy_definition(opts) do
    definition = Keyword.fetch!(opts, :definition)
    Free.lift(EngineFunctor.new(:deploy_definition, %{definition: definition}))
  end

  def activate_process(name), do: Free.lift(EngineFunctor.new(:activate_process, [name]))

  def activate_start_event(args), do: Free.lift(EngineFunctor.new(:activate_start_event, args))

  def subscribe(opts) do
    event_names =
      opts
      |> Keyword.fetch!(:to)
      |> List.wrap()

    event_handler = Keyword.fetch!(opts, :event_handler)

    Free.lift(
      EngineFunctor.new(:subscribe, %{
        event_names: event_names,
        event_handler: event_handler
      })
    )
  end
end
