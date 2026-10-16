defmodule Cyk.Simplify do
  @moduledoc """
  Simplificacion de gramaticas, en el orden visto en clase:

    paso 1  eliminar producciones epsilon
    paso 2  eliminar producciones unitarias
    paso 3  eliminar simbolos inutiles (no generadores y luego no alcanzables)

  Los tres pasos son calculos de punto fijo sobre conjuntos: se repite la
  misma regla hasta que el conjunto deja de crecer.
  """

  alias Cyk.Grammar

  # ------------------------------------------------------------------
  # paso 1: producciones epsilon
  # ------------------------------------------------------------------

  @doc "Elimina las producciones vacias. Devuelve {gramatica, anulables}."
  def epsilon(g) do
    anulables = nullable(g)

    reglas =
      Map.new(g.rules, fn {nt, alts} ->
        nuevas =
          alts
          |> Enum.flat_map(&combinaciones(&1, anulables))
          |> Enum.reject(&(&1 == []))
          |> Enum.uniq()

        {nt, nuevas}
      end)

    # si el inicial era anulable, la cadena vacia sigue en el lenguaje
    g = %{g | rules: reglas, accepts_empty: MapSet.member?(anulables, g.start)}
    {g, anulables}
  end

  @doc "Conjunto de no terminales que derivan epsilon."
  def nullable(g) do
    punto_fijo(MapSet.new(), fn acc ->
      Enum.reduce(g.rules, acc, fn {nt, alts}, acc ->
        # A es anulable si alguna alternativa esta formada solo por anulables
        if Enum.any?(alts, fn rhs -> Enum.all?(rhs, &MapSet.member?(acc, &1)) end),
          do: MapSet.put(acc, nt),
          else: acc
      end)
    end)
  end

  # genera todas las versiones del cuerpo quitando o dejando cada anulable
  defp combinaciones([], _anulables), do: [[]]

  defp combinaciones([s | resto], anulables) do
    colas = combinaciones(resto, anulables)
    con = Enum.map(colas, &[s | &1])
    if MapSet.member?(anulables, s), do: con ++ colas, else: con
  end

  # ------------------------------------------------------------------
  # paso 2: producciones unitarias
  # ------------------------------------------------------------------

  @doc "Elimina las producciones A -> B. Devuelve {gramatica, pares unitarios}."
  def unit(g) do
    pares = unit_pairs(g)

    reglas =
      Map.new(g.order, fn a ->
        alts =
          pares
          |> Enum.filter(fn {x, _} -> x == a end)
          |> Enum.flat_map(fn {_, b} ->
            # de cada B alcanzable por unitarias se copian solo las NO unitarias
            g.rules |> Map.get(b, []) |> Enum.reject(&unitaria?(g, &1))
          end)
          |> Enum.uniq()

        {a, alts}
      end)

    {%{g | rules: reglas}, pares}
  end

  @doc "Pares (A, B) tales que A =>* B usando solo producciones unitarias."
  def unit_pairs(g) do
    # se arranca con los reflexivos (A, A)
    inicial = MapSet.new(g.order, &{&1, &1})

    punto_fijo(inicial, fn acc ->
      Enum.reduce(acc, acc, fn {a, b}, acc ->
        g.rules
        |> Map.get(b, [])
        |> Enum.reduce(acc, fn
          [s], acc -> if Grammar.nonterminal?(g, s), do: MapSet.put(acc, {a, s}), else: acc
          _, acc -> acc
        end)
      end)
    end)
  end

  defp unitaria?(g, [s]), do: Grammar.nonterminal?(g, s)
  defp unitaria?(_g, _cuerpo), do: false

  # ------------------------------------------------------------------
  # paso 3: simbolos inutiles
  # ------------------------------------------------------------------

  @doc """
  Elimina los simbolos inutiles en dos sub pasos:
  primero los que no generan terminales, despues los no alcanzables.
  """
  def useless(g) do
    generadores = generating(g)
    g1 = conservar(g, generadores)

    alcanzables = reachable(g1)
    g2 = conservar(g1, alcanzables)

    {g2, %{generadores: generadores, alcanzables: alcanzables}}
  end

  @doc "No terminales que derivan alguna cadena de puros terminales."
  def generating(g) do
    terminales = Grammar.terminals(g)

    punto_fijo(MapSet.new(), fn acc ->
      Enum.reduce(g.rules, acc, fn {nt, alts}, acc ->
        util? =
          Enum.any?(alts, fn rhs ->
            Enum.all?(rhs, &(MapSet.member?(terminales, &1) or MapSet.member?(acc, &1)))
          end)

        if util?, do: MapSet.put(acc, nt), else: acc
      end)
    end)
  end

  @doc "No terminales alcanzables desde el simbolo inicial."
  def reachable(g) do
    punto_fijo(MapSet.new([g.start]), fn acc ->
      Enum.reduce(acc, acc, fn nt, acc ->
        g.rules
        |> Map.get(nt, [])
        |> Enum.reduce(acc, fn rhs, acc ->
          Enum.reduce(rhs, acc, fn s, acc ->
            if Grammar.nonterminal?(g, s), do: MapSet.put(acc, s), else: acc
          end)
        end)
      end)
    end)
  end

  # deja solo los no terminales del conjunto y borra las reglas que mencionan al resto
  defp conservar(g, conjunto) do
    reglas =
      g.rules
      |> Map.take(MapSet.to_list(conjunto))
      |> Map.new(fn {nt, alts} ->
        validas =
          Enum.filter(alts, fn rhs ->
            Enum.all?(rhs, fn s ->
              not Grammar.nonterminal?(g, s) or MapSet.member?(conjunto, s)
            end)
          end)

        {nt, validas}
      end)

    %{g | rules: reglas, order: Enum.filter(g.order, &MapSet.member?(conjunto, &1))}
  end

  # ------------------------------------------------------------------

  # repite la funcion hasta que el conjunto no cambia
  defp punto_fijo(actual, paso) do
    siguiente = paso.(actual)
    if siguiente == actual, do: actual, else: punto_fijo(siguiente, paso)
  end
end
