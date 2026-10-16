defmodule Cyk.Cnf do
  @moduledoc """
  Paso 4: conversion a Forma Normal de Chomsky.

  Despues de simplificar, toda produccion queda como A -> B C o A -> a.
  Son dos sub pasos:

    1. sacar los terminales que aparecen en cuerpos de dos o mas simbolos
    2. partir los cuerpos de tres o mas simbolos en cadenas binarias
  """

  alias Cyk.Grammar

  @doc "Convierte a CNF. Devuelve {gramatica, variables nuevas creadas}."
  def convert(g) do
    {g, terminales} = sacar_terminales(g)
    {g, encadenadas} = binarizar(g)
    {g, %{terminales: terminales, encadenadas: encadenadas}}
  end

  # ------------------------------------------------------------------
  # sub paso 1: terminales dentro de cuerpos largos
  # ------------------------------------------------------------------

  defp sacar_terminales(g) do
    Enum.reduce(g.order, {g, %{}}, fn nt, {g, mapa} ->
      {alts, {g, mapa}} =
        g.rules
        |> Map.get(nt, [])
        |> Enum.map_reduce({g, mapa}, fn rhs, acc ->
          # los cuerpos de un solo simbolo ya estan bien
          if length(rhs) < 2, do: {rhs, acc}, else: Enum.map_reduce(rhs, acc, &variable_de/2)
        end)

      {Grammar.put(g, nt, alts), mapa}
    end)
  end

  # devuelve la variable que representa al simbolo, creandola si es un terminal nuevo
  defp variable_de(simbolo, {g, mapa}) do
    cond do
      Grammar.nonterminal?(g, simbolo) ->
        {simbolo, {g, mapa}}

      Map.has_key?(mapa, simbolo) ->
        {mapa[simbolo], {g, mapa}}

      true ->
        nombre = Grammar.fresh(g, "T")
        {nombre, {Grammar.add(g, nombre, [[simbolo]]), Map.put(mapa, simbolo, nombre)}}
    end
  end

  # ------------------------------------------------------------------
  # sub paso 2: binarizacion
  # ------------------------------------------------------------------

  defp binarizar(g) do
    {g, _vistas, creadas} =
      Enum.reduce(g.order, {g, %{}, []}, fn nt, {g, vistas, creadas} ->
        {alts, {g, vistas, creadas}} =
          g.rules
          |> Map.get(nt, [])
          |> Enum.map_reduce({g, vistas, creadas}, fn rhs, acc ->
            if length(rhs) <= 2, do: {rhs, acc}, else: partir(rhs, acc)
          end)

        {Grammar.put(g, nt, alts), vistas, creadas}
      end)

    {g, creadas}
  end

  # A -> B C D  queda como  A -> B X1  junto con  X1 -> C D
  defp partir([primero | resto], acc) do
    {cola, acc} = encadenar(resto, acc)
    {[primero, cola], acc}
  end

  defp encadenar([a, b], acc), do: variable_par([a, b], acc)

  defp encadenar([a | resto], acc) do
    {cola, acc} = encadenar(resto, acc)
    variable_par([a, cola], acc)
  end

  # reutiliza la variable si ese mismo par ya se habia encadenado antes
  defp variable_par(par, {g, vistas, creadas}) do
    case Map.get(vistas, par) do
      nil ->
        nombre = Grammar.fresh(g, "X")
        {nombre, {Grammar.add(g, nombre, [par]), Map.put(vistas, par, nombre), creadas ++ [{nombre, par}]}}

      nombre ->
        {nombre, {g, vistas, creadas}}
    end
  end
end
