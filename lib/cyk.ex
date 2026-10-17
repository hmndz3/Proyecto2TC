defmodule Cyk do
  @moduledoc """
  Punto de entrada de la libreria: encadena los cuatro pasos y valida frases.
  """

  alias Cyk.{Cnf, Grammar, Parser, Simplify}

  defmodule Pipeline do
    @moduledoc "Gramatica en cada etapa, para poder mostrar el proceso completo."
    defstruct [:original, :sin_epsilon, :sin_unitarias, :sin_inutiles, :cnf, :info, :micros]
  end

  @doc "Aplica los pasos 1 a 4 y guarda el resultado intermedio de cada uno."
  def preparar(%Grammar{} = g) do
    {micros, pipeline} =
      :timer.tc(fn ->
        {g1, anulables} = Simplify.epsilon(g)
        {g2, pares} = Simplify.unit(g1)
        {g3, inutiles} = Simplify.useless(g2)
        {g4, variables} = Cnf.convert(g3)

        %Pipeline{
          original: g,
          sin_epsilon: g1,
          sin_unitarias: g2,
          sin_inutiles: g3,
          cnf: g4,
          info: %{
            anulables: anulables,
            pares_unitarios: pares,
            inutiles: inutiles,
            variables: variables
          }
        }
      end)

    %{pipeline | micros: micros}
  end

  @doc "Carga una gramatica desde archivo y la deja lista en CNF."
  def preparar_archivo(ruta), do: ruta |> Grammar.load!() |> preparar()

  @doc "Valida una frase contra la gramatica en CNF del pipeline."
  def validar(%Pipeline{cnf: cnf}, frase) when is_binary(frase) do
    Parser.run(cnf, tokenizar(cnf, frase))
  end

  def validar(%Grammar{} = cnf, palabras) when is_list(palabras) do
    Parser.run(cnf, palabras)
  end

  @doc "Tiempo promedio por corrida del CYK. Ver Cyk.Parser.measure/3."
  def medir(%Pipeline{cnf: cnf}, palabras, opts \\ []), do: Parser.measure(cnf, palabras, opts)

  @doc """
  Parte la frase en tokens.

  Separa por espacios, quita puntuacion al final de cada palabra y prueba la
  version en minusculas si el token tal cual no es un terminal conocido.
  """
  def tokenizar(cnf, frase) do
    terminales = Grammar.terminals(cnf)

    frase
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.replace(&1, ~r/[.,;:!?]+$/, ""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn token ->
      cond do
        MapSet.member?(terminales, token) -> token
        MapSet.member?(terminales, String.downcase(token)) -> String.downcase(token)
        true -> token
      end
    end)
  end

  @doc "Tokens que no aparecen como terminales de la gramatica."
  def desconocidos(cnf, palabras) do
    terminales = Grammar.terminals(cnf)
    Enum.reject(palabras, &MapSet.member?(terminales, &1))
  end
end
