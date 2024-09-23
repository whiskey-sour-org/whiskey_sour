defprotocol WhiskeySour.Core.Engines.InMemoryEngine.Interpreter do
  def eval(functor, engine_state, next_fun)
end
