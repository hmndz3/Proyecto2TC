defmodule Cyk.CLI do
  @moduledoc """
  Interfaz de terminal.

      mix cyk                                   gramatica de ingles por defecto
      mix cyk gramaticas/aritmetica.txt
      mix cyk --frase "she eats a cake"         valida una sola frase y sale
      mix cyk --pasos                           muestra las gramaticas intermedias
      mix cyk --sin-ventana                     no abre el arbol en el navegador
      mix cyk --repetir 25                      mide el tiempo sobre varias corridas
  """

  alias Cyk.{Grammar, Svg, Tree, UI}

  @por_defecto "gramaticas/ingles.txt"
  @maximo_tabla 12

  @opciones [
    frase: :string,
    pasos: :boolean,
    tabla: :boolean,
    sin_ventana: :boolean,
    repetir: :integer,
    ayuda: :boolean
  ]

  def main(argv) do
    # el terminal de Windows necesita esto para los acentos y los bordes
    :io.setopts(:standard_io, encoding: :unicode)

    {opts, resto, _} = OptionParser.parse(argv, strict: @opciones, aliases: [h: :ayuda])

    if opts[:ayuda] do
      IO.puts(@moduledoc)
    else
      ruta = List.first(resto) || @por_defecto
      ejecutar(ruta, opts)
    end
  end

  defp ejecutar(ruta, opts) do
    IO.puts(UI.banner("CYK · Proyecto 2", "Teoría de la Computación · simplificación de gramáticas y parsing"))

    case File.exists?(ruta) do
      false ->
        IO.puts(UI.fallo("  No se encontró la gramática: #{ruta}\n"))

      true ->
        gramatica = Grammar.load!(ruta)
        pipeline = Cyk.preparar(gramatica)

        resumen(ruta, gramatica)
        mostrar_pasos(pipeline, opts[:pasos])
        mostrar_cnf(pipeline)

        case opts[:frase] do
          nil -> ciclo(pipeline, opts)
          frase -> validar(pipeline, frase, opts)
        end
    end
  end

  # ------------------------------------------------------------------
  # gramatica
  # ------------------------------------------------------------------

  defp resumen(ruta, g) do
    IO.puts(UI.campo("Archivo", ruta))
    IO.puts(UI.campo("Variables", length(g.order)))
    IO.puts(UI.campo("Producciones", Grammar.size(g)))
    IO.puts(UI.campo("Símbolo inicial", g.start))
  end

  defp mostrar_pasos(p, detalle?) do
    IO.puts(UI.seccion("Simplificación"))
    i = p.info

    paso(1, "Eliminación de producciones ε", p.original, p.sin_epsilon, detalle?, [
      {"Anulables", UI.lista(Enum.sort(i.anulables), 8)}
    ])

    paso(2, "Eliminación de producciones unitarias", p.sin_epsilon, p.sin_unitarias, detalle?, [
      {"Pares unitarios", i.pares_unitarios |> Enum.sort() |> Enum.map_join(" ", fn {a, b} -> "(#{a},#{b})" end)}
    ])

    no_gen = diferencia(p.sin_unitarias.order, i.inutiles.generadores)
    no_alc = diferencia(p.sin_unitarias.order, i.inutiles.alcanzables) -- no_gen

    paso(3, "Eliminación de símbolos inútiles", p.sin_unitarias, p.sin_inutiles, detalle?, [
      {"No generadores", UI.lista(no_gen, 8)},
      {"No alcanzables", UI.lista(no_alc, 8)}
    ])

    nuevas =
      (i.variables.terminales |> Enum.map(fn {t, v} -> "#{v}→#{t}" end) |> Enum.sort()) ++
        Enum.map(i.variables.encadenadas, fn {v, cuerpo} -> "#{v}→#{Enum.join(cuerpo, " ")}" end)

    paso(4, "Forma Normal de Chomsky", p.sin_inutiles, p.cnf, detalle?, [
      {"Variables nuevas", UI.lista(nuevas, 8)}
    ])

    IO.puts("")
    IO.puts(UI.campo("Tiempo total", "#{ms(p.micros * 1000)} ms"))
    IO.puts(UI.campo("¿Es CNF válida?", if(Grammar.cnf?(p.cnf), do: UI.exito("sí"), else: UI.fallo("no"))))
  end

  defp paso(n, titulo, antes, despues, detalle?, datos) do
    IO.puts("")
    IO.puts(UI.paso(n, titulo))
    Enum.each(datos, fn {etiqueta, valor} -> IO.puts(UI.campo(etiqueta, valor)) end)
    IO.puts(UI.campo("Producciones", UI.flecha(Grammar.size(antes), Grammar.size(despues))))

    if detalle? do
      IO.puts("")
      IO.puts(UI.tenue(UI.sangrar(Grammar.to_text(despues), 6)))
    end
  end

  defp mostrar_cnf(p) do
    IO.puts(UI.seccion("Gramática en CNF"))
    IO.puts(UI.sangrar(Grammar.to_text(p.cnf), 4))
  end

  defp diferencia(orden, conjunto), do: Enum.reject(orden, &MapSet.member?(conjunto, &1))

  # ------------------------------------------------------------------
  # ciclo interactivo
  # ------------------------------------------------------------------

  defp ciclo(p, opts) do
    IO.puts(UI.seccion("Validación"))
    IO.puts(UI.tenue("    Escribe una frase y Enter.  :ayuda para ver los comandos.\n"))
    leer(p, opts)
  end

  defp leer(p, opts) do
    case IO.gets(UI.acento("  › ")) do
      :eof ->
        IO.puts("")

      {:error, _} ->
        IO.puts("")

      linea ->
        comando(String.trim(linea), p, opts)
    end
  end

  defp comando("", p, opts), do: leer(p, opts)
  defp comando(salir, _p, _opts) when salir in [":salir", ":q"], do: IO.puts(UI.tenue("\n  Listo.\n"))

  defp comando(":ayuda", p, opts) do
    ayuda()
    leer(p, opts)
  end

  defp comando(":gramatica", p, opts) do
    volcar(p.original)
    leer(p, opts)
  end

  defp comando(":cnf", p, opts) do
    volcar(p.cnf)
    leer(p, opts)
  end

  defp comando(":pasos", p, opts) do
    mostrar_pasos(p, true)
    leer(p, opts)
  end

  defp comando(frase, p, opts) do
    validar(p, frase, opts)
    leer(p, opts)
  end

  defp ayuda do
    IO.puts("")
    IO.puts(UI.campo(":gramatica", "muestra la gramática original"))
    IO.puts(UI.campo(":cnf", "muestra la gramática en CNF"))
    IO.puts(UI.campo(":pasos", "repite el detalle de la simplificación"))
    IO.puts(UI.campo(":salir", "termina el programa"))
    IO.puts("")
    true
  end

  defp volcar(g) do
    IO.puts("")
    IO.puts(UI.sangrar(Grammar.to_text(g), 4))
    IO.puts("")
    true
  end

  # ------------------------------------------------------------------
  # validacion de una frase
  # ------------------------------------------------------------------

  defp validar(p, frase, opts) do
    palabras = Cyk.tokenizar(p.cnf, frase)
    desconocidos = Cyk.desconocidos(p.cnf, palabras)

    resultado = Cyk.validar(p, frase)
    medicion = Cyk.medir(p, palabras, corridas: opts[:repetir])

    IO.puts("")
    IO.puts(UI.campo("Frase", frase))
    IO.puts(UI.campo("Tokens", "#{length(palabras)}  [#{Enum.join(palabras, " ")}]"))

    if desconocidos != [] do
      IO.puts(UI.campo("Desconocidos", UI.fallo(Enum.join(desconocidos, ", "))))
    end

    IO.puts("")
    IO.puts(UI.veredicto(resultado.accepted))
    IO.puts("")

    IO.puts(UI.campo("Tiempo CYK", tiempo_texto(medicion)))

    if resultado.accepted do
      IO.puts(UI.campo("Árboles posibles", arboles_texto(resultado.trees)))
    end

    if length(palabras) <= @maximo_tabla and length(palabras) > 0 do
      IO.puts("")
      IO.puts(UI.tenue("    Tabla CYK"))
      IO.puts(UI.sangrar(UI.tabla_cyk(resultado), 4))
    end

    if resultado.accepted, do: mostrar_arbol(resultado, frase, opts)

    IO.puts("")
    true
  end

  defp tiempo_texto(%{nanos: nanos, corridas: corridas}) do
    "#{ms(nanos)} ms  " <>
      UI.tenue("(#{micros(nanos)} µs · promedio de #{corridas} corrida(s))")
  end

  defp arboles_texto(1), do: "1"
  defp arboles_texto(n), do: "#{n}  " <> UI.tenue("(la gramática es ambigua para esta frase)")

  defp mostrar_arbol(resultado, frase, opts) do
    arbol = Tree.from_result(resultado)

    IO.puts("")
    IO.puts(UI.tenue("    Árbol de derivación"))
    IO.puts(UI.sangrar(Tree.to_text(arbol), 4))

    unless opts[:sin_ventana] do
      info = "#{resultado.trees} árbol(es) · #{ms(resultado.nanos)} ms"
      ruta = Svg.write(arbol, frase, info)
      Svg.open(ruta)
      IO.puts("")
      IO.puts(UI.campo("Ventana", UI.tenue(ruta)))
    end
  end

  defp ms(nanos), do: :erlang.float_to_binary(nanos / 1_000_000, decimals: 4)
  defp micros(nanos), do: :erlang.float_to_binary(nanos / 1000, decimals: 2)
end
