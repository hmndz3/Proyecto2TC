# Proyecto 2 — Algoritmo CYK

Teoría de la Computación · Universidad del Valle de Guatemala

Simplificación de gramáticas libres de contexto, conversión a Forma Normal de
Chomsky y parsing con el algoritmo CYK, implementado en Elixir.

## Requisitos

Solo hace falta **Elixir 1.14 o superior** (incluye Erlang/OTP). El proyecto no
usa ninguna librería externa, así que no hay nada que instalar después de clonar.

```bash
elixir --version
```

Si no está instalado: <https://elixir-lang.org/install.html> (en Windows el
instalador de `elixir-lang.org` o `scoop install elixir` incluyen Erlang).

## Cómo correrlo

```bash
mix cyk
```

Arranca con la gramática del enunciado y queda en modo interactivo: escribís una
frase, Enter, y devuelve el veredicto, el tiempo y el árbol.

Otras formas:

```bash
mix cyk gramaticas/aritmetica.txt                  # otra gramática
mix cyk --frase "she eats a cake with a fork"      # una sola frase y sale
mix cyk --pasos                                    # muestra cada gramática intermedia
mix cyk --sin-ventana                              # no abre el árbol en el navegador
mix cyk --repetir 1000                             # fija las corridas de la medición
mix cyk --ayuda
```

Comandos dentro del modo interactivo: `:gramatica`, `:cnf`, `:pasos`, `:salir`.

Las pruebas:

```bash
mix test
```

## Formato de las gramáticas

```
# los comentarios empiezan con numeral
S   -> NP VP
VP  -> VP PP | V NP | eats
X   -> + T X | e
```

- `->` separa la cabeza del cuerpo, `|` separa alternativas.
- **Los símbolos van separados por espacios.** Por eso `id` es un solo token y
  `( E )` son tres. Lo mismo al escribir la frase: `( id + id ) * id`.
- `e` representa épsilon.
- Un símbolo es **no terminal** si aparece como cabeza de alguna producción;
  todo lo demás es terminal.
- El **símbolo inicial** es la cabeza de la primera producción.

Gramáticas incluidas en `gramaticas/`:

| Archivo | Contenido |
|---|---|
| `ingles.txt` | la del enunciado del proyecto |
| `aritmetica.txt` | expresiones aritméticas (el archivo `1.txt` del curso) |
| `aritmetica-cnf.txt` | el CNF de referencia (`1-cnf.txt`), usado en las pruebas |
| `ambigua.txt` | `E -> E + E \| E * E \| ( E ) \| id`, para ver el contador de árboles |

## Estructura

```
lib/cyk/
├── grammar.ex    lectura del formato, struct Grammar, impresión
├── simplify.ex   pasos 1 a 3: épsilon, unitarias, inútiles
├── cnf.ex        paso 4: Forma Normal de Chomsky
├── parser.ex     algoritmo CYK, tabla dinámica y medición de tiempo
├── tree.ex       árbol de derivación desde los backpointers
├── svg.ex        dibujo del árbol y apertura en ventana aparte
├── ui.ex         formato de la salida en terminal
└── cli.ex        interfaz de línea de comandos
```

Los primeros cinco módulos son Elixir puro sin efectos secundarios; `ui.ex`,
`svg.ex` y `cli.ex` solo se encargan de mostrar.

## El algoritmo

### Simplificación

Los cuatro pasos, en el orden visto en clase:

1. **Eliminación de producciones ε** — se calcula el conjunto de anulables y
   por cada cuerpo se generan todas las versiones quitando o dejando cada
   símbolo anulable.
2. **Eliminación de producciones unitarias** — se arman los pares `(A, B)` con
   `A ⇒* B` partiendo de los reflexivos, y a cada `A` se le copian las
   producciones **no** unitarias de cada `B`.
3. **Eliminación de símbolos inútiles** — primero los que no generan terminales,
   después los no alcanzables desde el inicial.
4. **Forma Normal de Chomsky** — se sacan los terminales que aparecen en cuerpos
   de dos o más símbolos a variables nuevas (`T1 -> +`) y se parten los cuerpos
   largos en cadenas binarias (`A -> B X1`, `X1 -> C D`).

Los tres primeros son cálculos de punto fijo: se repite la misma regla sobre un
conjunto hasta que deja de crecer. En Elixir eso es una función recursiva que
compara el conjunto anterior con el nuevo, sin estado mutable.

### CYK

La tabla es un `Map` con llave `{i, longitud}`, donde `i` es la posición inicial
de la subcadena. Cada celda guarda `%{no_terminal => backpointers}`.

No hace falta mutar nada: CYK llena la tabla por **longitud creciente**, así que
al calcular una celda las que necesita ya están escritas y solo se leen. Eso
convierte la programación dinámica en un `reduce` con la tabla como acumulador.

Los backpointers son lo que permite reconstruir el árbol en lugar de devolver
solo un booleano, y también contar cuántas derivaciones distintas existen.

Complejidad: **O(n³ · |G|)**.

### Sobre la medición del tiempo

El reloj monotónico del sistema operativo tiene una resolución de unos 100 µs en
Windows, y una validación típica tarda ~15 µs. Cronometrar una sola corrida
devuelve 0. Por eso la validación se repite hasta superar un umbral y se divide
el total entre el número de corridas; de paso eso deja atrás el calentamiento
del JIT de la BEAM, que hace que la primera ejecución sea notablemente más lenta
que las siguientes.

## Notas

- La gramática del enunciado **ya está en Forma Normal de Chomsky**: todas sus
  producciones son `A -> B C` o `A -> a`, no tiene ε ni unitarias ni símbolos
  inútiles. Los cuatro pasos corren igual y la dejan intacta. La que sí ejercita
  la simplificación completa es `aritmetica.txt`.
- Nuestro CNF de `aritmetica.txt` da 20 producciones, las mismas del
  `aritmetica-cnf.txt` del curso, con los nombres de las variables nuevas
  cambiados (`L=T1`, `R=T2`, `P=T3`, `M=T4`, `Z=X1`, `W=X2`, `V=X3`). Como esos
  nombres son arbitrarios, la prueba compara **equivalencia**: que ambas
  gramáticas acepten y rechacen exactamente las mismas cadenas.
- Las frases aceptadas son sintácticamente correctas, no necesariamente
  semánticamente. `the cake eats` se acepta.
- El árbol se abre en una ventana aparte generando un HTML con el SVG embebido y
  pasándoselo al visor por defecto del sistema, así no hace falta ninguna
  librería gráfica.
