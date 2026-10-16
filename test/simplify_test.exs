defmodule SimplifyTest do
  use ExUnit.Case, async: true

  alias Cyk.{Grammar, Simplify}

  describe "paso 1 - produccciones epsilon" do
    # Corto 2, problema 3
    setup do
      g =
        Grammar.parse("""
        S -> A B C d
        A -> B C
        B -> b B | e
        C -> c C | e
        """)

      %{g: g}
    end

    test "detecta los anulables", %{g: g} do
      assert Simplify.nullable(g) == MapSet.new(["A", "B", "C"])
    end

    test "genera todas las combinaciones sin epsilon", %{g: g} do
      {sin_eps, _} = Simplify.epsilon(g)

      assert Enum.sort(sin_eps.rules["S"]) ==
               Enum.sort([
                 ~w(A B C d),
                 ~w(B C d),
                 ~w(A C d),
                 ~w(A B d),
                 ~w(C d),
                 ~w(B d),
                 ~w(A d),
                 ~w(d)
               ])
    end

    test "no deja ninguna produccion vacia", %{g: g} do
      {sin_eps, _} = Simplify.epsilon(g)
      refute Enum.any?(Grammar.productions(sin_eps), fn {_, cuerpo} -> cuerpo == [] end)
    end

    test "marca la gramatica si el inicial era anulable" do
      g = Grammar.parse("S -> A\nA -> a | e")
      {sin_eps, _} = Simplify.epsilon(g)
      assert sin_eps.accepts_empty
    end
  end

  describe "paso 2 - producciones unitarias" do
    # Corto 2, problema 5
    setup do
      %{g: Grammar.parse("S -> a S | A | C\nA -> a\nB -> a a\nC -> a C b")}
    end

    test "arma los pares unitarios incluyendo los reflexivos", %{g: g} do
      pares = Simplify.unit_pairs(g)

      assert MapSet.member?(pares, {"S", "S"})
      assert MapSet.member?(pares, {"S", "A"})
      assert MapSet.member?(pares, {"S", "C"})
      refute MapSet.member?(pares, {"S", "B"})
    end

    test "copia las producciones no unitarias", %{g: g} do
      {sin_unit, _} = Simplify.unit(g)
      assert Enum.sort(sin_unit.rules["S"]) == Enum.sort([~w(a S), ~w(a), ~w(a C b)])
    end

    test "no quedan producciones A -> B", %{g: g} do
      {sin_unit, _} = Simplify.unit(g)

      refute Enum.any?(Grammar.productions(sin_unit), fn
               {_, [s]} -> Grammar.nonterminal?(sin_unit, s)
               _ -> false
             end)
    end

    test "las unitarias transitivas tambien se resuelven" do
      g = Grammar.parse("S -> A\nA -> B\nB -> b")
      {sin_unit, _} = Simplify.unit(g)
      assert sin_unit.rules["S"] == [~w(b)]
    end
  end

  describe "paso 3 - simbolos inutiles" do
    setup do
      {g, _} = "S -> a S | A | C\nA -> a\nB -> a a\nC -> a C b" |> Grammar.parse() |> Simplify.unit()
      %{g: g}
    end

    test "C no genera terminales", %{g: g} do
      refute MapSet.member?(Simplify.generating(g), "C")
      assert MapSet.member?(Simplify.generating(g), "A")
    end

    test "A y B dejan de ser alcanzables al quitar C", %{g: g} do
      {limpia, _} = Simplify.useless(g)
      assert limpia.order == ["S"]
    end

    test "queda S -> a S | a", %{g: g} do
      {limpia, _} = Simplify.useless(g)
      assert Enum.sort(limpia.rules["S"]) == Enum.sort([~w(a S), ~w(a)])
    end

    test "los no alcanzables se eliminan" do
      g = Grammar.parse("S -> a\nZ -> b")
      {limpia, _} = Simplify.useless(g)
      assert limpia.order == ["S"]
    end
  end
end
