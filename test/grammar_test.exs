defmodule GrammarTest do
  use ExUnit.Case, async: true

  alias Cyk.Grammar

  test "lee el formato con alternativas y espacios" do
    g = Grammar.parse("E -> T X\nF -> ( E ) | id")

    assert g.rules["E"] == [~w(T X)]
    assert g.rules["F"] == [["(", "E", ")"], ["id"]]
  end

  test "el simbolo inicial es la cabeza de la primera produccion" do
    assert Grammar.parse("E -> T\nT -> a").start == "E"
  end

  test "ignora comentarios y lineas en blanco" do
    g = Grammar.parse("# titulo\n\nS -> a   # al final\n")
    assert g.rules["S"] == [~w(a)]
  end

  test "e se guarda como cuerpo vacio" do
    assert Grammar.parse("X -> + X | e").rules["X"] == [["+", "X"], []]
  end

  test "un simbolo es no terminal si aparece como cabeza" do
    g = Grammar.parse("S -> a S b")

    assert Grammar.nonterminal?(g, "S")
    refute Grammar.nonterminal?(g, "a")
    assert Grammar.terminals(g) == MapSet.new(~w(a b))
  end

  test "acumula las alternativas de cabezas repetidas" do
    g = Grammar.parse("S -> a\nS -> b")
    assert g.rules["S"] == [~w(a), ~w(b)]
    assert g.order == ["S"]
  end

  test "fresh evita colisionar con variables existentes" do
    g = Grammar.parse("T -> a\nT1 -> b")
    assert Grammar.fresh(g, "T") == "T2"
  end

  test "to_text vuelve a imprimir el formato de entrada" do
    texto = "E -> T X | id\nX -> + T X | e"
    assert texto |> Grammar.parse() |> Grammar.to_text() == texto
  end

  test "cnf? reconoce las formas validas" do
    assert Grammar.parse("S -> A B\nA -> a\nB -> b") |> Grammar.cnf?()
    refute Grammar.parse("S -> A B C\nA -> a\nB -> b\nC -> c") |> Grammar.cnf?()
    refute Grammar.parse("S -> A\nA -> a") |> Grammar.cnf?()
    refute Grammar.parse("S -> a B\nB -> b") |> Grammar.cnf?()
  end

  test "rechaza una linea sin flecha" do
    assert_raise ArgumentError, fn -> Grammar.parse("S : a") end
  end
end
