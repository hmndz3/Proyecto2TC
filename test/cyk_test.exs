defmodule CykTest do
  use ExUnit.Case, async: true

  alias Cyk.Tree

  setup_all do
    %{
      ingles: Cyk.preparar_archivo("gramaticas/ingles.txt"),
      aritmetica: Cyk.preparar_archivo("gramaticas/aritmetica.txt"),
      ambigua: Cyk.preparar_archivo("gramaticas/ambigua.txt")
    }
  end

  describe "frases que SI estan en el lenguaje" do
    @aceptadas [
      "she eats a cake with a fork",
      "he drinks the beer",
      "the cat drinks the beer",
      "she cooks",
      "a dog cuts the meat with a knife",
      "he eats the soup in the oven",
      # sintacticamente correcta aunque no tenga sentido: el enunciado lo advierte
      "the cake eats"
    ]

    test "todas se aceptan", %{ingles: p} do
      for frase <- @aceptadas do
        assert Cyk.validar(p, frase).accepted, "deberia aceptar: #{frase}"
      end
    end
  end

  describe "frases que NO estan en el lenguaje" do
    @rechazadas [
      "eats she a cake",
      "a cat with the dog",
      "she eats a",
      "cat the drinks beer",
      "she eats a cake with",
      "banana"
    ]

    test "todas se rechazan", %{ingles: p} do
      for frase <- @rechazadas do
        refute Cyk.validar(p, frase).accepted, "no deberia aceptar: #{frase}"
      end
    end
  end

  describe "detalles del resultado" do
    test "la mayuscula inicial no afecta", %{ingles: p} do
      assert Cyk.validar(p, "She eats a cake").accepted
      assert Cyk.validar(p, "The cat drinks the beer.").accepted
    end

    test "la cadena vacia se rechaza", %{ingles: p} do
      refute Cyk.validar(p, "").accepted
    end

    test "reporta el tiempo", %{ingles: p} do
      assert Cyk.validar(p, "she cooks").nanos >= 0
    end

    test "cuenta un solo arbol cuando no hay ambiguedad", %{ingles: p} do
      assert Cyk.validar(p, "she eats a cake with a fork").trees == 1
    end

    test "cuenta dos arboles en la gramatica ambigua", %{ambigua: p} do
      assert Cyk.validar(p, "id + id * id").trees == 2
    end

    test "la ambiguedad crece con la cadena", %{ambigua: p} do
      # numeros de Catalan: 1, 2, 5 para 2, 3 y 4 operadores
      assert Cyk.validar(p, "id + id").trees == 1
      assert Cyk.validar(p, "id + id * id").trees == 2
      assert Cyk.validar(p, "id + id * id + id").trees == 5
    end
  end

  describe "expresiones aritmeticas" do
    test "acepta las bien formadas", %{aritmetica: p} do
      for frase <- ["id", "id + id", "( id )", "( id + id ) * id", "id * ( id + id )"] do
        assert Cyk.validar(p, frase).accepted, "deberia aceptar: #{frase}"
      end
    end

    test "rechaza las mal formadas", %{aritmetica: p} do
      for frase <- ["+ id", "id +", "( id", "id id", "* id *"] do
        refute Cyk.validar(p, frase).accepted, "no deberia aceptar: #{frase}"
      end
    end
  end

  describe "arbol de derivacion" do
    test "tiene una hoja por palabra", %{ingles: p} do
      resultado = Cyk.validar(p, "she eats a cake with a fork")
      arbol = Tree.from_result(resultado)

      assert Tree.leaves(arbol) == 7
    end

    test "la raiz es el simbolo inicial", %{ingles: p} do
      arbol = p |> Cyk.validar("he drinks the beer") |> Tree.from_result()
      assert arbol.label == "S"
    end

    test "no hay arbol si la frase se rechaza", %{ingles: p} do
      assert p |> Cyk.validar("a cat with the dog") |> Tree.from_result() == nil
    end

    test "las hojas reconstruyen la frase original", %{ingles: p} do
      frase = "a dog cuts the meat with a knife"
      arbol = p |> Cyk.validar(frase) |> Tree.from_result()

      assert hojas(arbol) == String.split(frase)
    end
  end

  defp hojas(%Tree{word: w}) when is_binary(w), do: [w]
  defp hojas(%Tree{children: cs}), do: Enum.flat_map(cs, &hojas/1)
end
