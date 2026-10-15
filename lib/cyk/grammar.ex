defmodule Cyk.Grammar do
  @moduledoc """
  Gramatica libre de contexto G = (V, T, P, S).

  Formato de archivo:

      # comentario
      S  -> NP VP
      VP -> V NP | eats
      X  -> + T X | e

  Reglas del formato:
    - "->" separa cabeza y cuerpo, "|" separa alternativas
    - los simbolos van separados por espacios ("id" es un token, "( E )" son tres)
    - "e" representa epsilon
    - un simbolo es no terminal si aparece como cabeza de alguna produccion
    - el simbolo inicial es la cabeza de la primera produccion
  """

  defstruct start: nil, rules: %{}, order: [], accepts_empty: false

  @type rhs :: [String.t()]
  @type t :: %__MODULE__{
          start: String.t() | nil,
          rules: %{String.t() => [rhs]},
          order: [String.t()],
          accepts_empty: boolean()
        }

  @epsilon ~w(e eps epsilon ε &)

  # ------------------------------------------------------------------
  # lectura
  # ------------------------------------------------------------------

  def load!(path), do: path |> File.read!() |> parse()

  def parse(text) do
    text
    |> String.split(~r/\r?\n/)
    |> Enum.map(&limpiar/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce(%__MODULE__{}, &leer_linea/2)
    |> definir_inicial()
  end

  # quita comentarios y espacios sobrantes
  defp limpiar(linea) do
    linea |> String.replace(~r/#.*$/, "") |> String.trim()
  end

  defp leer_linea(linea, g) do
    case String.split(linea, "->", parts: 2) do
      [izq, der] ->
        cabeza = String.trim(izq)
        alternativas = der |> String.split("|") |> Enum.map(&simbolos/1)
        add(g, cabeza, alternativas)

      _ ->
        raise ArgumentError, "linea sin '->': #{inspect(linea)}"
    end
  end

  # separa por espacios; epsilon se guarda como lista vacia
  defp simbolos(alternativa) do
    case String.split(String.trim(alternativa), ~r/\s+/, trim: true) do
      [uno] -> if uno in @epsilon, do: [], else: [uno]
      varios -> varios
    end
  end

  defp definir_inicial(%{order: []} = g), do: g
  defp definir_inicial(%{order: [primero | _]} = g), do: %{g | start: primero}

  # ------------------------------------------------------------------
  # construccion
  # ------------------------------------------------------------------

  @doc "Agrega alternativas a un no terminal, conservando el orden de aparicion."
  def add(g, cabeza, alternativas) do
    reglas = Map.update(g.rules, cabeza, Enum.uniq(alternativas), &Enum.uniq(&1 ++ alternativas))
    orden = if cabeza in g.order, do: g.order, else: g.order ++ [cabeza]
    %{g | rules: reglas, order: orden}
  end

  @doc "Reemplaza por completo las alternativas de un no terminal."
  def put(g, cabeza, alternativas) do
    %{g | rules: Map.put(g.rules, cabeza, Enum.uniq(alternativas))}
  end

  @doc "Nombre de variable nueva que no colisione con las existentes (T1, T2, ...)."
  def fresh(g, base), do: fresh(g, base, 1)

  defp fresh(g, base, n) do
    nombre = base <> Integer.to_string(n)
    if nonterminal?(g, nombre), do: fresh(g, base, n + 1), else: nombre
  end

  # ------------------------------------------------------------------
  # consultas
  # ------------------------------------------------------------------

  def nonterminal?(g, simbolo), do: Map.has_key?(g.rules, simbolo)

  def nonterminals(g), do: MapSet.new(g.order)

  def terminals(g) do
    for {_, alts} <- g.rules,
        rhs <- alts,
        s <- rhs,
        not nonterminal?(g, s),
        into: MapSet.new(),
        do: s
  end

  @doc "Lista plana de producciones {cabeza, cuerpo}."
  def productions(g) do
    for nt <- g.order, rhs <- Map.get(g.rules, nt, []), do: {nt, rhs}
  end

  def size(g), do: g |> productions() |> length()

  @doc "Verifica que toda produccion sea A -> B C o A -> a."
  def cnf?(g) do
    Enum.all?(productions(g), fn
      {_, [b, c]} -> nonterminal?(g, b) and nonterminal?(g, c)
      {_, [t]} -> not nonterminal?(g, t)
      _ -> false
    end)
  end

  # ------------------------------------------------------------------
  # salida
  # ------------------------------------------------------------------

  def to_text(g) do
    ancho = ancho_cabezas(g.order)

    g.order
    |> Enum.map(fn nt ->
      cuerpo =
        case Map.get(g.rules, nt, []) do
          [] -> "(sin producciones)"
          alts -> alts |> Enum.map_join(" | ", &mostrar/1)
        end

      String.pad_trailing(nt, ancho) <> " -> " <> cuerpo
    end)
    |> Enum.join("\n")
  end

  defp ancho_cabezas([]), do: 1
  defp ancho_cabezas(orden), do: orden |> Enum.map(&String.length/1) |> Enum.max()

  defp mostrar([]), do: "e"
  defp mostrar(simbolos), do: Enum.join(simbolos, " ")
end
