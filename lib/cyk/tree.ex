defmodule Cyk.Tree do
  @moduledoc """
  Arbol de derivacion reconstruido desde los backpointers de la tabla CYK.

  Un nodo interno tiene dos hijos (regla A -> B C) y un preterminal
  guarda la palabra (regla A -> a).
  """

  defstruct [:label, :word, children: []]

  @type t :: %__MODULE__{label: String.t(), word: String.t() | nil, children: [t]}

  @doc "Arma un arbol desde la celda {i, longitud} para el no terminal dado."
  def build(tabla, i, longitud, nt) do
    case tabla |> Map.get({i, longitud}, %{}) |> Map.get(nt) do
      nil ->
        nil

      backpointers ->
        # se toma el primero: cualquiera de los backpointers da un arbol valido
        case hd(backpointers) do
          {:terminal, palabra} ->
            %__MODULE__{label: nt, word: palabra}

          {:bin, k, b, c} ->
            %__MODULE__{
              label: nt,
              children: [
                build(tabla, i, k, b),
                build(tabla, i + k, longitud - k, c)
              ]
            }
        end
    end
  end

  @doc "Arbol de la frase completa, o nil si no fue aceptada."
  def from_result(%{accepted: false}), do: nil
  def from_result(%{words: []}), do: nil

  def from_result(result) do
    build(result.table, 0, length(result.words), result.start)
  end

  # ------------------------------------------------------------------
  # salida en texto
  # ------------------------------------------------------------------

  def to_text(nil), do: "(sin arbol)"

  def to_text(nodo) do
    [nodo.label | ramas(hijos(nodo), "")] |> Enum.join("\n")
  end

  defp hijos(%__MODULE__{word: palabra}) when is_binary(palabra), do: [{:hoja, palabra}]
  defp hijos(%__MODULE__{children: cs}), do: cs

  defp ramas([], _prefijo), do: []

  defp ramas(lista, prefijo) do
    total = length(lista)

    lista
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {hijo, idx} ->
      {rama, sangria} =
        if idx == total, do: {"└── ", "    "}, else: {"├── ", "│   "}

      case hijo do
        {:hoja, palabra} ->
          [prefijo <> rama <> palabra]

        nodo ->
          [prefijo <> rama <> nodo.label | ramas(hijos(nodo), prefijo <> sangria)]
      end
    end)
  end

  @doc "Cantidad de hojas (palabras) del arbol."
  def leaves(nil), do: 0
  def leaves(%__MODULE__{word: w}) when is_binary(w), do: 1
  def leaves(%__MODULE__{children: cs}), do: cs |> Enum.map(&leaves/1) |> Enum.sum()

  @doc "Profundidad maxima del arbol."
  def depth(nil), do: 0
  def depth(%__MODULE__{word: w}) when is_binary(w), do: 2
  def depth(%__MODULE__{children: cs}), do: 1 + (cs |> Enum.map(&depth/1) |> Enum.max())
end
