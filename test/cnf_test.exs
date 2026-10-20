defmodule CnfTest do
  use ExUnit.Case, async: true

  alias Cyk.{Grammar, Parser}

  describe "forma normal de Chomsky" do
    test "toda produccion queda como A -> B C o A -> a" do
      for archivo <- ~w(ingles aritmetica ambigua) do
        p = Cyk.preparar_archivo("gramaticas/#{archivo}.txt")

        assert Grammar.cnf?(p.cnf), "#{archivo}.txt no quedo en CNF"
      end
    end

    test "la gramatica del enunciado ya estaba en CNF" do
      p = Cyk.preparar_archivo("gramaticas/ingles.txt")
      assert Grammar.size(p.original) == Grammar.size(p.cnf)
    end

    test "reutiliza la variable cuando el mismo par se repite" do
      # ( E ) aparece en F y se arrastra a E y T: debe salir una sola X
      p = Cyk.preparar_archivo("gramaticas/aritmetica.txt")
      encadenadas = p.info.variables.encadenadas

      assert length(Enum.uniq_by(encadenadas, fn {_, cuerpo} -> cuerpo end)) ==
               length(encadenadas)
    end

    test "coincide en tamano con el CNF de referencia" do
      p = Cyk.preparar_archivo("gramaticas/aritmetica.txt")
      referencia = Grammar.load!("gramaticas/aritmetica-cnf.txt")

      assert Grammar.size(p.cnf) == Grammar.size(referencia)
      assert length(p.cnf.order) == length(referencia.order)
    end
  end

  describe "equivalencia con el CNF de referencia" do
    # los nombres de las variables nuevas son arbitrarios, asi que la unica
    # comparacion que tiene sentido es si ambas aceptan las mismas cadenas
    @casos [
      ["id"],
      ["id", "+", "id"],
      ["id", "*", "id"],
      ["id", "+", "id", "*", "id"],
      ["(", "id", ")"],
      ["(", "id", "+", "id", ")", "*", "id"],
      ["id", "+", "(", "id", "*", "id", ")"],
      ["+", "id"],
      ["id", "+"],
      ["(", "id"],
      ["id", "id"],
      ["*"],
      []
    ]

    test "acepta y rechaza exactamente lo mismo" do
      nuestra = Cyk.preparar_archivo("gramaticas/aritmetica.txt").cnf
      referencia = Grammar.load!("gramaticas/aritmetica-cnf.txt")

      for palabras <- @casos do
        a = Parser.recognize(nuestra, palabras).accepted
        b = Parser.recognize(referencia, palabras).accepted

        assert a == b, "difieren en #{inspect(palabras)}: nuestra=#{a} referencia=#{b}"
      end
    end
  end
end
