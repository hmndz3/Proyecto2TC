defmodule Cyk.Parser do
  @moduledoc """
  Algoritmo CYK sobre una gramatica en CNF.

  La tabla es un Map con llave {i, longitud}, donde i es la posicion inicial
  de la subcadena. Cada celda guarda %{no_terminal => backpointers}, y cada
  backpointer dice de donde salio ese no terminal:

      {:terminal, palabra}   la celda de longitud 1
      {:bin, k, B, C}        la regla A -> B C partiendo en k

  No hace falta mutar nada: CYK llena la tabla por longitud creciente, asi
  que al calcular una celda las que necesita ya estan escritas y solo se leen.
  """

  alias Cyk.Grammar

  defmodule Result do
    @moduledoc "Resultado de una validacion."
    defstruct [:accepted, :table, :words, :nanos, :trees, :start]
  end

  @doc "Valida la lista de palabras contra la gramatica (que debe estar en CNF)."
  def run(g, palabras) do
    inicio = :erlang.monotonic_time(:nanosecond)
    resultado = recognize(g, palabras)
    %{resultado | nanos: :erlang.monotonic_time(:nanosecond) - inicio}
  end

  @doc "Igual que run/2 pero sin cronometrar."
  def recognize(g, palabras) do
    tabla = llenar(g, palabras)
    n = length(palabras)

    aceptada =
      if n == 0, do: g.accepts_empty, else: Map.has_key?(Map.get(tabla, {0, n}, %{}), g.start)

    %Result{
      accepted: aceptada,
      table: tabla,
      words: palabras,
      trees: contar_arboles(tabla, n, g.start),
      start: g.start
    }
  end

  @doc """
  Mide el tiempo por corrida.

  El reloj monotonico del sistema operativo tiene una resolucion de ~100 us en
  Windows, asi que cronometrar una sola corrida devuelve 0. Se repite la
  validacion hasta pasar un umbral y se divide; asi tambien se deja atras el
  calentamiento del JIT de la BEAM.
  """
  def measure(g, palabras, opts \\ []) do
    minimo = Keyword.get(opts, :minimo_ms, 20) * 1_000_000

    case Keyword.get(opts, :corridas) do
      nil -> calibrar(g, palabras, 1, minimo)
      n -> resumen(g, palabras, n)
    end
  end

  defp calibrar(g, palabras, n, minimo) do
    resultado = resumen(g, palabras, n)

    if resultado.total >= minimo or n >= 1_000_000,
      do: resultado,
      else: calibrar(g, palabras, n * 4, minimo)
  end

  defp resumen(g, palabras, n) do
    inicio = :erlang.monotonic_time(:nanosecond)
    Enum.each(1..n//1, fn _ -> recognize(g, palabras) end)
    total = :erlang.monotonic_time(:nanosecond) - inicio

    %{nanos: div(total, n), corridas: n, total: total}
  end

  # ------------------------------------------------------------------
  # tabla dinamica
  # ------------------------------------------------------------------

  defp llenar(g, palabras) do
    n = length(palabras)
    unarias = indice_unario(g)
    binarias = indice_binario(g)

    # longitud 1: que no terminales producen cada palabra
    base =
      palabras
      |> Enum.with_index()
      |> Map.new(fn {palabra, i} ->
        producen = Map.get(unarias, palabra, [])
        {{i, 1}, Map.new(producen, &{&1, [{:terminal, palabra}]})}
      end)

    # longitudes 2..n
    Enum.reduce(2..n//1, base, fn longitud, tabla ->
      Enum.reduce(0..(n - longitud)//1, tabla, fn i, tabla ->
        Map.put(tabla, {i, longitud}, celda(tabla, binarias, i, longitud))
      end)
    end)
  end

  # combina cada particion de la subcadena en dos mitades ya calculadas
  defp celda(tabla, binarias, i, longitud) do
    Enum.reduce(1..(longitud - 1)//1, %{}, fn k, acc ->
      izquierda = Map.get(tabla, {i, k}, %{})
      derecha = Map.get(tabla, {i + k, longitud - k}, %{})

      for {b, _} <- izquierda,
          {c, _} <- derecha,
          a <- Map.get(binarias, {b, c}, []),
          reduce: acc do
        acc -> Map.update(acc, a, [{:bin, k, b, c}], &[{:bin, k, b, c} | &1])
      end
    end)
  end

  # %{palabra => [no terminales]} para las reglas A -> a
  defp indice_unario(g) do
    for {nt, alts} <- g.rules, [t] <- alts, not Grammar.nonterminal?(g, t), reduce: %{} do
      acc -> Map.update(acc, t, [nt], &[nt | &1])
    end
  end

  # %{{B, C} => [no terminales]} para las reglas A -> B C
  defp indice_binario(g) do
    for {nt, alts} <- g.rules, [b, c] <- alts, reduce: %{} do
      acc -> Map.update(acc, {b, c}, [nt], &[nt | &1])
    end
  end

  # ------------------------------------------------------------------
  # conteo de arboles (ambiguedad)
  # ------------------------------------------------------------------

  # recorre la tabla por longitud creciente acumulando cuantos arboles produce cada celda
  defp contar_arboles(_tabla, 0, _inicial), do: 0

  defp contar_arboles(tabla, n, inicial) do
    memo =
      Enum.reduce(1..n//1, %{}, fn longitud, memo ->
        Enum.reduce(0..(n - longitud)//1, memo, fn i, memo ->
          tabla
          |> Map.get({i, longitud}, %{})
          |> Enum.reduce(memo, fn {nt, bps}, memo ->
            Map.put(memo, {i, longitud, nt}, suma(bps, memo, i, longitud))
          end)
        end)
      end)

    Map.get(memo, {0, n, inicial}, 0)
  end

  defp suma(backpointers, memo, i, longitud) do
    Enum.reduce(backpointers, 0, fn
      {:terminal, _}, acc ->
        acc + 1

      {:bin, k, b, c}, acc ->
        acc + Map.get(memo, {i, k, b}, 0) * Map.get(memo, {i + k, longitud - k, c}, 0)
    end)
  end

  @doc "No terminales de una celda, ordenados."
  def cell(result, i, longitud) do
    result.table |> Map.get({i, longitud}, %{}) |> Map.keys() |> Enum.sort()
  end
end
