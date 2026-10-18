defmodule Mix.Tasks.Cyk do
  @moduledoc "Ejecuta el analizador CYK. Ver `mix cyk --ayuda`."
  @shortdoc "Analizador CYK con simplificacion de gramaticas"

  use Mix.Task

  @impl Mix.Task
  def run(args), do: Cyk.CLI.main(args)
end
