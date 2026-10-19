defmodule Cyk.Svg do
  @moduledoc """
  Dibuja el arbol de derivacion y lo abre en una ventana aparte.

  Genera un HTML con el SVG embebido y se lo pasa al visor por defecto del
  sistema, asi no hace falta ninguna libreria grafica.
  """

  alias Cyk.Tree

  @ancho_columna 96
  @alto_nivel 78
  @margen 48

  # ------------------------------------------------------------------
  # posicionamiento
  # ------------------------------------------------------------------

  # cada hoja ocupa una columna; un nodo interno se centra sobre sus hijos
  defp ubicar(%Tree{word: palabra} = nodo, columna, nivel) when is_binary(palabra) do
    {%{etiqueta: nodo.label, palabra: palabra, x: columna, y: nivel, hijos: []}, columna + 1}
  end

  defp ubicar(%Tree{children: hijos} = nodo, columna, nivel) do
    {ubicados, siguiente} =
      Enum.map_reduce(hijos, columna, fn hijo, c -> ubicar(hijo, c, nivel + 1) end)

    x = Enum.sum(Enum.map(ubicados, & &1.x)) / length(ubicados)
    {%{etiqueta: nodo.label, palabra: nil, x: x, y: nivel, hijos: ubicados}, siguiente}
  end

  defp aplanar(nodo), do: [nodo | Enum.flat_map(nodo.hijos, &aplanar/1)]

  defp aristas(nodo) do
    Enum.flat_map(nodo.hijos, fn hijo -> [{nodo, hijo} | aristas(hijo)] end)
  end

  # ------------------------------------------------------------------
  # dibujo
  # ------------------------------------------------------------------

  @doc "Devuelve el SVG del arbol como string."
  def render(nil), do: ~s(<svg xmlns="http://www.w3.org/2000/svg"></svg>)

  def render(arbol) do
    {raiz, columnas} = ubicar(arbol, 0, 0)
    nodos = aplanar(raiz)
    niveles = nodos |> Enum.map(& &1.y) |> Enum.max()

    # el nivel extra es para las palabras, que van debajo de los preterminales
    ancho = max(columnas, 1) * @ancho_columna + 2 * @margen
    alto = (niveles + 1) * @alto_nivel + 2 * @margen

    cuerpo =
      Enum.map_join(aristas(raiz), "\n", &linea/1) <>
        "\n" <> Enum.map_join(nodos, "\n", &caja/1)

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{ancho}" height="#{alto}" viewBox="0 0 #{ancho} #{alto}">
      <rect width="100%" height="100%" fill="#ffffff"/>
      #{cuerpo}
    </svg>
    """
  end

  defp cx(nodo), do: @margen + nodo.x * @ancho_columna + @ancho_columna / 2
  defp cy(nodo), do: @margen + nodo.y * @alto_nivel

  defp linea({padre, hijo}) do
    ~s(  <line x1="#{cx(padre)}" y1="#{cy(padre) + 14}" x2="#{cx(hijo)}" y2="#{cy(hijo) - 16}" stroke="#c4c8cf" stroke-width="1.4"/>)
  end

  # no terminal: caja clara con borde; la palabra va debajo en otro estilo
  defp caja(nodo) do
    x = cx(nodo)
    y = cy(nodo)
    ancho = max(String.length(nodo.etiqueta) * 10 + 20, 40)

    etiqueta = """
      <rect x="#{x - ancho / 2}" y="#{y - 16}" width="#{ancho}" height="30" rx="6" fill="#eef1f6" stroke="#aab2c0" stroke-width="1"/>
      <text x="#{x}" y="#{y + 4}" text-anchor="middle" font-family="Consolas, monospace" font-size="15" fill="#1f2328">#{escapar(nodo.etiqueta)}</text>
    """

    case nodo.palabra do
      nil ->
        etiqueta

      palabra ->
        hoja_y = y + @alto_nivel

        etiqueta <>
          """
            <line x1="#{x}" y1="#{y + 14}" x2="#{x}" y2="#{hoja_y - 18}" stroke="#c4c8cf" stroke-width="1.4"/>
            <text x="#{x}" y="#{hoja_y}" text-anchor="middle" font-family="Consolas, monospace" font-size="15" font-weight="600" fill="#2f6b4f">#{escapar(palabra)}</text>
          """
    end
  end

  defp escapar(texto) do
    texto
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  # ------------------------------------------------------------------
  # archivo y ventana
  # ------------------------------------------------------------------

  @doc "Escribe el arbol como HTML y devuelve la ruta."
  def write(arbol, frase, info, destino \\ "arbol.html") do
    File.write!(destino, html(arbol, frase, info))
    Path.expand(destino)
  end

  defp html(arbol, frase, info) do
    """
    <!doctype html>
    <html lang="es">
    <head>
      <meta charset="utf-8">
      <title>Arbol de derivacion</title>
      <style>
        body { margin: 0; padding: 32px; background: #f6f7f9; color: #1f2328;
               font-family: -apple-system, Segoe UI, Roboto, sans-serif; }
        h1   { font-size: 17px; font-weight: 600; margin: 0 0 4px; }
        p    { margin: 0 0 20px; color: #6b7280; font-size: 13px; }
        code { font-family: Consolas, monospace; color: #1f2328; }
        .lienzo { background: #fff; border: 1px solid #e3e6ea; border-radius: 10px;
                  padding: 16px; overflow: auto; }
      </style>
    </head>
    <body>
      <h1>Árbol de derivación</h1>
      <p><code>#{escapar(frase)}</code> &nbsp;·&nbsp; #{escapar(info)}</p>
      <div class="lienzo">#{render(arbol)}</div>
    </body>
    </html>
    """
  end

  @doc """
  Abre el archivo con el programa por defecto del sistema.

  En Windows se usa explorer.exe y no `cmd /c start`: con start, el navegador
  hereda la salida estandar del puerto y System.cmd se queda esperando a que
  lo cierres. explorer.exe lanza el visor y devuelve de inmediato (con codigo
  de salida 1, que aqui se ignora).
  """
  def open(ruta) do
    case :os.type() do
      {:win32, _} -> System.cmd("explorer.exe", [windows(ruta)])
      {:unix, :darwin} -> System.cmd("open", [ruta])
      _ -> System.cmd("xdg-open", [ruta])
    end

    :ok
  rescue
    _ -> {:error, :sin_visor}
  end

  defp windows(ruta), do: String.replace(ruta, "/", "\\")
end
