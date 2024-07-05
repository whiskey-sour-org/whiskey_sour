defmodule WhiskeySour.Core.Engine.EngineAlgebra do
  @moduledoc false
  alias WhiskeySour.Core.Engine.EngineFunctor
  alias WhiskeySour.Core.Free

  def create_instance(opts) when is_list(opts) do
    %{
      bpmn_process_id: bpmn_process_id,
      correlation_ref: correlation_ref
    } =
      opts
      |> Keyword.validate!([:bpmn_process_id, correlation_ref: nil])
      |> Map.new()

    Free.bind(fetch_process_definition_key(bpmn_process_id: bpmn_process_id, correlation_ref: correlation_ref), fn
      {:ok, %{process_key: process_key}} ->
        Free.bind(
          activate_process(bpmn_process_id: bpmn_process_id, process_key: process_key, correlation_ref: correlation_ref),
          &Free.return/1
        )

      {:error, _reason} = error ->
        Free.return(error)
    end)
  end

  def deploy_definition(opts) do
    valid_args =
      opts
      |> Keyword.validate!([:definition, correlation_ref: nil])
      |> Map.new()

    Free.lift(EngineFunctor.new(:deploy_definition, valid_args))
  end

  def fetch_process_definition_key(opts) do
    bpmn_process_id = Keyword.fetch!(opts, :bpmn_process_id)

    Free.lift(EngineFunctor.new(:fetch_process_definition_key, %{bpmn_process_id: bpmn_process_id}))
  end

  def activate_process(opts) do
    valid_args =
      opts
      |> Keyword.validate!([:bpmn_process_id, :process_key, correlation_ref: nil])
      |> Map.new()

    Free.lift(EngineFunctor.new(:activate_process, valid_args))
  end

  def activate_start_event(opts) do
    valid_args =
      opts
      |> Keyword.validate!([:process_instance, correlation_ref: nil])
      |> Map.new()

    Free.lift(EngineFunctor.new(:activate_start_event, valid_args))
  end

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
