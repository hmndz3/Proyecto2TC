defmodule Cyk.UI do
  @moduledoc "Formato de la salida en terminal: titulos, cajas, tablas y colores."

  @ancho 76

  # ------------------------------------------------------------------
  # colores
  # ------------------------------------------------------------------

  def tenue(t), do: pintar(t, IO.ANSI.light_black())
  def acento(t), do: pintar(t, IO.ANSI.cyan())
  def exito(t), do: pintar(t, IO.ANSI.green())
  def fallo(t), do: pintar(t, IO.ANSI.red())
  def fuerte(t), do: pintar(t, IO.ANSI.bright())

  defp pintar(texto, codigo) do
    if IO.ANSI.enabled?(), do: codigo <> texto <> IO.ANSI.reset(), else: texto
  end

  # ------------------------------------------------------------------
  # bloques
  # ------------------------------------------------------------------

  def banner(titulo, subtitulo) do
    linea = String.duplicate("─", @ancho - 2)

    [
      "",
      acento("╭" <> linea <> "╮"),
      acento("│") <> "  " <> fuerte(relleno(titulo, @ancho - 4)) <> acento("│"),
      acento("│") <> "  " <> tenue(relleno(subtitulo, @ancho - 4)) <> acento("│"),
      acento("╰" <> linea <> "╯"),
      ""
    ]
    |> Enum.join("\n")
  end

  def seccion(titulo) do
    resto = @ancho - String.length(titulo) - 6
    "\n" <> acento("── " <> titulo <> " " <> String.duplicate("─", max(resto, 2))) <> "\n"
  end

  def paso(numero, titulo) do
    "  " <> fuerte("Paso #{numero}") <> tenue(" · ") <> titulo
  end

  def campo(etiqueta, valor) do
    "    " <> tenue(relleno(etiqueta, 18)) <> to_string(valor)
  end

  def veredicto(true), do: bloque("SÍ pertenece al lenguaje", &exito/1)
  def veredicto(false), do: bloque("NO pertenece al lenguaje", &fallo/1)

  defp bloque(texto, color) do
    ancho = String.length(texto) + 6
    borde = String.duplicate("─", ancho)

    [
      "    " <> color.("╭" <> borde <> "╮"),
      "    " <> color.("│   " <> texto <> "   │"),
      "    " <> color.("╰" <> borde <> "╯")
    ]
    |> Enum.join("\n")
  end

  def sangrar(texto, espacios \\ 4) do
    pad = String.duplicate(" ", espacios)

    texto
    |> String.split("\n")
    |> Enum.map_join("\n", &(pad <> &1))
  end

  def lista([], _), do: tenue("(ninguno)")

  def lista(items, maximo) do
    textos = Enum.map(items, &to_string/1)

    if length(textos) > maximo do
      Enum.join(Enum.take(textos, maximo), ", ") <> tenue(" … (+#{length(textos) - maximo})")
    else
      Enum.join(textos, ", ")
    end
  end

  def flecha(antes, despues) when antes == despues, do: tenue("#{antes} (sin cambios)")
  def flecha(antes, despues), do: "#{antes} → #{despues}"

  # ------------------------------------------------------------------
  # tabla CYK
  # ------------------------------------------------------------------

  @doc "Dibuja la tabla triangular: una fila por longitud de subcadena."
  def tabla_cyk(result) do
    palabras = result.words
    n = length(palabras)

    celdas =
      for longitud <- 1..n//1, i <- 0..(n - longitud)//1, into: %{} do
        contenido =
          result.table
          |> Map.get({i, longitud}, %{})
          |> Map.keys()
          |> Enum.sort()
          |> case do
            [] -> "·"
            nts -> Enum.join(nts, ",")
          end

        {{longitud, i}, contenido}
      end

    ancho =
      [celdas |> Map.values() |> Enum.map(&String.length/1), Enum.map(palabras, &String.length/1)]
      |> List.flatten()
      |> Enum.max()
      |> max(3)

    encabezado =
      "      " <> Enum.map_join(palabras, " ", &relleno(&1, ancho))

    filas =
      for longitud <- 1..n//1 do
        cuerpo =
          for i <- 0..(n - longitud)//1 do
            relleno(celdas[{longitud, i}], ancho)
          end

        tenue(String.pad_leading("#{longitud}", 3) <> " │ ") <> Enum.join(cuerpo, " ")
      end

    Enum.join([tenue(encabezado) | filas], "\n")
  end

  # ------------------------------------------------------------------

  # rellena a la derecha contando caracteres visibles
  defp relleno(texto, ancho) do
    texto = to_string(texto)
    falta = ancho - String.length(texto)
    if falta > 0, do: texto <> String.duplicate(" ", falta), else: texto
  end
end
