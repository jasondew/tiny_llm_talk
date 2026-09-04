defmodule TinyLlmTalkWeb.FigureComponents do
  @moduledoc """
  The pictures: heatmaps, distributions, the loss curve, and the box the whole
  talk keeps coming back to.

  Every one of these is handed plain Elixir terms straight out of
  `TinyLlmTalk.Model`, which is the reason the deck is a Phoenix app. There is
  no export step and no image to go stale; a figure is the model's own numbers,
  rendered.

  Colour follows the job. Magnitude gets one hue, light to dark, so a heatmap
  reads as more and less rather than as a rainbow. Text always wears text
  colours, never a series colour.
  """

  use Phoenix.Component

  alias TinyLlmTalk.Chart

  @doc """
  The recurring figure: words in, a box, and 32 probabilities out.

  It appears at the start and again at the end with the lid off, which is the
  spine of the arc. Same function, and now you know what is in the box.
  """
  attr :label, :string, required: true
  attr :input, :string, default: "the words so far"
  attr :distribution, :list, default: nil
  attr :words, :list, default: nil
  attr :class, :string, default: nil

  def function_box(assigns) do
    ~H"""
    <div class={["function-box", @class]}>
      <div class="function-box__input">{@input}</div>
      <div class="function-box__arrow" aria-hidden="true">&rarr;</div>
      <div class="function-box__box">{@label}</div>
      <div class="function-box__arrow" aria-hidden="true">&rarr;</div>
      <div class="function-box__output">
        <.spark :if={@distribution} values={@distribution} />
        <p class="function-box__caption">32 probabilities, one per word</p>
      </div>
    </div>
    """
  end

  @doc "A distribution as a row of thin bars, unlabelled. Shape, not values."
  attr :values, :list, required: true

  def spark(assigns) do
    assigns = assign(assigns, peak: Enum.max(assigns.values))

    ~H"""
    <div class="spark">
      <span :for={value <- @values} class="spark__bar" style={"height: #{bar_height(value, @peak)}%"} />
    </div>
    """
  end

  @doc """
  The top few words of a distribution, as labelled bars.

  Direct labels rather than a hover tooltip: nobody in the seventh row can
  hover, and a number on every bar is noise. Only the ones being talked about.
  """
  attr :values, :list, required: true
  attr :words, :list, required: true
  attr :top, :integer, default: 6
  attr :highlight, :list, default: []
  attr :include, :list, default: [], doc: "words shown even when they are not in the top few"
  attr :class, :string, default: nil

  def bars(assigns) do
    assigns =
      assign(assigns,
        rows: top_rows(assigns.values, assigns.words, assigns.top, assigns.include)
      )

    ~H"""
    <div class={["bars", @class]}>
      <div :for={row <- @rows} class={["bars__row", row.word in @highlight && "bars__row--lit"]}>
        <span class="bars__label">{row.word}</span>
        <span class="bars__track">
          <span class="bars__fill" style={"width: #{row.percent}%"} />
        </span>
        <span class="bars__value">{format_percent(row.probability)}</span>
      </div>
    </div>
    """
  end

  @doc """
  One vector as a row of the writer's heatmap: a label, then a cell per entry
  with the number printed in it. Colour is magnitude, so a negative entry is
  as dark as its positive twin and only the printed sign tells them apart.
  """
  attr :label, :string, required: true
  attr :values, :list, required: true
  attr :cell, :integer, default: 72
  attr :class, :string, default: nil

  def vector(assigns) do
    peak = assigns.values |> Enum.map(&abs/1) |> Enum.max(fn -> 1.0 end)
    assigns = assign(assigns, peak: max(peak, 1.0e-9))

    ~H"""
    <div
      class={["heatmap heatmap--compact vector", @class]}
      style={"--heatmap-cell: #{@cell}px; --heatmap-columns: #{length(@values)}"}
    >
      <div class="heatmap__row-label vector__label">{@label}</div>
      <div
        :for={value <- @values}
        class="heatmap__cell vector__cell"
        style={"--heat: #{Float.round(abs(value) / @peak, 3)}"}
      >
        {format_signed(value)}
      </div>
    </div>
    """
  end

  @doc """
  Two vectors drawn as arrows from the origin, and their dot product as a
  picture: the shadow `b` casts on `a`, times the length of `a`. Two entries
  each, because a graph has two axes.

  With `interactive`, the arrow tips can be dragged. The hook turns pointer
  positions back into coordinates, snaps them to the half grid so the
  numbers stay readable, and sends them up as the controls `vector_a` and
  `vector_b`, which `TinyLlmTalkWeb.Controls.vector/3` reads back.
  """
  attr :id, :string, default: "vector-graph"
  attr :a, :list, required: true
  attr :b, :list, required: true
  attr :shadow, :boolean, default: false, doc: "draw the projection of b onto a"
  attr :interactive, :boolean, default: false, doc: "let the arrow tips be dragged"
  attr :reach, :float, default: 4.5, doc: "how far each axis runs from the origin"
  attr :size, :integer, default: 420

  def vector_graph(assigns) do
    [ax, ay] = assigns.a
    [bx, by] = assigns.b
    dot = ax * bx + ay * by
    along = if ax == 0.0 and ay == 0.0, do: 0.0, else: dot / (ax * ax + ay * ay)
    pad = 24
    unit = (assigns.size - 2 * pad) / (2 * assigns.reach)
    origin = assigns.size / 2
    place = fn {x, y} -> {origin + x * unit, origin - y * unit} end

    assigns =
      assign(assigns,
        origin: {origin, origin},
        unit: unit,
        a_tip: place.({ax, ay}),
        b_tip: place.({bx, by}),
        shadow_tip: place.({ax * along, ay * along}),
        ticks:
          for(
            n <- -floor(assigns.reach)..floor(assigns.reach),
            n != 0,
            do: {n, place.({n, 0}), place.({0, n})}
          ),
        dot: dot
      )

    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".VectorDrag">
      export default {
        mounted() {
          const svg = this.el
          const originX = parseFloat(svg.dataset.originX)
          const originY = parseFloat(svg.dataset.originY)
          const unit = parseFloat(svg.dataset.unit)
          const reach = parseFloat(svg.dataset.reach)
          let dragging = null
          let lastSent = 0

          const toVector = (event) => {
            const point = new DOMPoint(event.clientX, event.clientY).matrixTransform(svg.getScreenCTM().inverse())
            const snap = (value) => Math.max(-reach, Math.min(reach, Math.round(value * 2) / 2))
            return [snap((point.x - originX) / unit), snap((originY - point.y) / unit)]
          }

          const send = (event, force) => {
            const now = performance.now()
            if (!force && now - lastSent < 40) return
            lastSent = now
            const [x, y] = toVector(event)
            this.pushEvent("control", {name: `vector_${dragging}`, value: `${x},${y}`})
          }

          svg.addEventListener("pointerdown", (event) => {
            const handle = event.target.closest("[data-vector]")
            if (!handle) return
            dragging = handle.dataset.vector
            svg.setPointerCapture(event.pointerId)
            event.preventDefault()
            send(event, true)
          })
          svg.addEventListener("pointermove", (event) => { if (dragging) send(event, false) })
          const release = (event) => { if (dragging) { send(event, true); dragging = null } }
          svg.addEventListener("pointerup", release)
          svg.addEventListener("pointercancel", release)
        }
      }
    </script>
    <svg
      id={@id}
      phx-hook={@interactive && ".VectorDrag"}
      data-origin-x={elem(@origin, 0)}
      data-origin-y={elem(@origin, 1)}
      data-unit={@unit}
      data-reach={@reach}
      class={["vector-graph", @interactive && "vector-graph--interactive"]}
      viewBox={"0 0 #{@size} #{@size}"}
      width={@size}
      height={@size}
      role="img"
      aria-label={"a and b on a graph, dot product #{format_signed(@dot)}"}
    >
      <defs>
        <marker
          id={"#{@id}-arrow-a"}
          viewBox="0 0 10 10"
          refX="9"
          refY="5"
          markerWidth="8"
          markerHeight="8"
          orient="auto-start-reverse"
        >
          <path d="M 0 0 L 10 5 L 0 10 z" class="vector-graph__head vector-graph__head--a" />
        </marker>
        <marker
          id={"#{@id}-arrow-b"}
          viewBox="0 0 10 10"
          refX="9"
          refY="5"
          markerWidth="8"
          markerHeight="8"
          orient="auto-start-reverse"
        >
          <path d="M 0 0 L 10 5 L 0 10 z" class="vector-graph__head vector-graph__head--b" />
        </marker>
      </defs>
      <line
        x1="8"
        y1={elem(@origin, 1)}
        x2={@size - 8}
        y2={elem(@origin, 1)}
        class="vector-graph__axis"
      />
      <line
        x1={elem(@origin, 0)}
        y1="8"
        x2={elem(@origin, 0)}
        y2={@size - 8}
        class="vector-graph__axis"
      />
      <g :for={{n, {tx, ty}, {sx, sy}} <- @ticks} class="vector-graph__tick">
        <line x1={tx} y1={ty - 4} x2={tx} y2={ty + 4} />
        <text x={tx} y={ty + 16} text-anchor="middle">{n}</text>
        <line x1={sx - 4} y1={sy} x2={sx + 4} y2={sy} />
        <text x={sx - 8} y={sy + 4} text-anchor="end">{n}</text>
      </g>
      <g :if={@shadow}>
        <line
          x1={elem(@a_tip, 0)}
          y1={elem(@a_tip, 1)}
          x2={elem(@b_tip, 0)}
          y2={elem(@b_tip, 1)}
          class="vector-graph__drop"
        />
        <line
          x1={elem(@origin, 0)}
          y1={elem(@origin, 1)}
          x2={elem(@shadow_tip, 0)}
          y2={elem(@shadow_tip, 1)}
          class="vector-graph__shadow"
        />
      </g>
      <line
        x1={elem(@origin, 0)}
        y1={elem(@origin, 1)}
        x2={elem(@a_tip, 0)}
        y2={elem(@a_tip, 1)}
        class="vector-graph__vector vector-graph__vector--a"
        marker-end={"url(##{@id}-arrow-a)"}
      />
      <line
        x1={elem(@origin, 0)}
        y1={elem(@origin, 1)}
        x2={elem(@b_tip, 0)}
        y2={elem(@b_tip, 1)}
        class="vector-graph__vector vector-graph__vector--b"
        marker-end={"url(##{@id}-arrow-b)"}
      />
      <text
        x={elem(@a_tip, 0) + 14}
        y={elem(@a_tip, 1) + 6}
        class="vector-graph__name vector-graph__name--a"
      >
        a
      </text>
      <text
        x={elem(@b_tip, 0) + 14}
        y={elem(@b_tip, 1) + 6}
        class="vector-graph__name vector-graph__name--b"
      >
        b
      </text>
      <g :if={@interactive}>
        <circle
          cx={elem(@a_tip, 0)}
          cy={elem(@a_tip, 1)}
          r="18"
          data-vector="a"
          class="vector-graph__handle vector-graph__handle--a"
        />
        <circle
          cx={elem(@b_tip, 0)}
          cy={elem(@b_tip, 1)}
          r="18"
          data-vector="b"
          class="vector-graph__handle vector-graph__handle--b"
        />
      </g>
      <text :if={@shadow} x={@size - 12} y="28" text-anchor="end" class="vector-graph__dot">
        a &middot; b = {format_signed(@dot)}
      </text>
    </svg>
    """
  end

  @doc """
  A matrix as colour. One hue, light to dark, because the value being shown is
  a magnitude and a magnitude has an order.

  `highlight` rings the cells being talked about, so the thing said out loud
  and the thing on screen are the same thing.
  """
  attr :values, :list, required: true
  attr :row_labels, :list, required: true
  attr :column_labels, :list, required: true
  attr :highlight, :list, default: []
  attr :show_values, :boolean, default: false
  attr :scale, :atom, default: :linear, values: [:linear, :sqrt]
  attr :cell, :integer, default: 13
  attr :class, :string, default: nil

  def heatmap(assigns) do
    assigns =
      assign(assigns,
        rows: heatmap_rows(assigns.values, assigns.row_labels, assigns.highlight, assigns.scale)
      )

    ~H"""
    <div
      class={["heatmap", @class]}
      style={"--heatmap-cell: #{@cell}px; --heatmap-columns: #{length(@column_labels)}"}
    >
      <div class="heatmap__corner" />
      <div :for={label <- @column_labels} class="heatmap__column-label"><span>{label}</span></div>
      <%= for row <- @rows do %>
        <div class={["heatmap__row-label", row.lit? && "heatmap__row-label--lit"]}>{row.label}</div>
        <div
          :for={cell <- row.cells}
          class={["heatmap__cell", cell.lit? && "heatmap__cell--lit"]}
          style={"--heat: #{cell.intensity}"}
          title={cell.title}
        >
          {if @show_values and cell.value >= 0.005, do: format_weight(cell.value)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  A loss curve, with the two lines every loss chart in this talk carries:
  knowing nothing at the top, and the floor a one-word model cannot cross.

  With `draw`, the line draws itself from left to right over a few seconds, so
  the room watches the loss fall rather than being shown that it fell.
  """
  attr :losses, :list, required: true
  attr :knowing_nothing, :float, required: true
  attr :floor, :float, required: true
  attr :floor_label, :string, default: "one-word floor"
  attr :series_label, :string, default: "held-out loss"
  attr :line, :boolean, default: true, doc: "show the curve at all"
  attr :draw, :boolean, default: false, doc: "animate the curve in when it appears"
  attr :steps, :integer, default: nil, doc: "fix the x axis here, for a run still going"
  attr :width, :integer, default: 900
  attr :height, :integer, default: 400

  def loss_chart(assigns) do
    assigns = assign(assigns, chart: loss_chart_scale(assigns))

    ~H"""
    <figure class="chart">
      <svg
        viewBox={"0 0 #{@width} #{@height}"}
        class="chart__svg"
        role="img"
        aria-label={"#{@series_label} against training step"}
      >
        <line
          :for={value <- Chart.ticks(@chart.y_domain, 5)}
          class="chart__grid"
          x1={Chart.x(@chart, elem(@chart.x_domain, 0))}
          x2={Chart.x(@chart, elem(@chart.x_domain, 1))}
          y1={Chart.y(@chart, value)}
          y2={Chart.y(@chart, value)}
        />
        <text
          :for={value <- Chart.ticks(@chart.y_domain, 5)}
          class="chart__tick"
          x={Chart.x(@chart, elem(@chart.x_domain, 0)) - 12}
          y={Chart.y(@chart, value) + 5}
          text-anchor="end"
        >
          {:erlang.float_to_binary(value, decimals: 1)}
        </text>
        <text
          :for={value <- Chart.ticks(@chart.x_domain, 5)}
          class="chart__tick"
          x={Chart.x(@chart, value)}
          y={@height - 14}
          text-anchor="middle"
        >
          {round(value)}
        </text>

        <line
          class="chart__reference"
          x1={Chart.x(@chart, elem(@chart.x_domain, 0))}
          x2={Chart.x(@chart, elem(@chart.x_domain, 1))}
          y1={Chart.y(@chart, @knowing_nothing)}
          y2={Chart.y(@chart, @knowing_nothing)}
        />
        <text
          class="chart__reference-label"
          x={Chart.x(@chart, elem(@chart.x_domain, 1))}
          y={Chart.y(@chart, @knowing_nothing) - 10}
          text-anchor="end"
        >
          knowing nothing &middot; ln(32) = {:erlang.float_to_binary(@knowing_nothing, decimals: 3)}
        </text>

        <line
          class="chart__reference chart__reference--floor"
          x1={Chart.x(@chart, elem(@chart.x_domain, 0))}
          x2={Chart.x(@chart, elem(@chart.x_domain, 1))}
          y1={Chart.y(@chart, @floor)}
          y2={Chart.y(@chart, @floor)}
        />
        <text
          class="chart__reference-label chart__reference-label--floor"
          x={Chart.x(@chart, elem(@chart.x_domain, 1))}
          y={Chart.y(@chart, @floor) + 26}
          text-anchor="end"
        >
          {@floor_label} &middot; {:erlang.float_to_binary(@floor, decimals: 3)}
        </text>

        <polyline
          :if={@line}
          class={["chart__line", @draw && "chart__line--draw"]}
          points={Chart.polyline(@chart, @losses)}
        />
      </svg>
      <figcaption class="chart__caption">{@series_label}, against training step</figcaption>
    </figure>
    """
  end

  @doc "What a figure shows before anyone has run `mix talk.train`."
  attr :what, :string, required: true

  def untrained(assigns) do
    ~H"""
    <div class="untrained">
      <p class="untrained__title">no checkpoint yet</p>
      <p class="untrained__body">
        {@what} needs trained weights. Run <code>mix talk.train</code>, which takes
        about a minute and a half, and this figure fills in.
      </p>
    </div>
    """
  end

  ## PRIVATE FUNCTIONS

  defp bar_height(_value, peak) when peak <= 0.0, do: 0
  defp bar_height(value, peak), do: Float.round(value / peak * 100, 1)

  # The top few, plus any word that must be shown regardless: a draw from the
  # tail of a distribution is still the draw, and a bar chart that hides it
  # looks like it is about some other word.
  defp top_rows(values, words, count, include) do
    peak = Enum.max(values)

    ranked =
      values |> Enum.zip(words) |> Enum.sort_by(fn {probability, _word} -> -probability end)

    top = Enum.take(ranked, count)
    forced = Enum.filter(ranked, fn {_probability, word} -> word in include end)

    (top ++ forced)
    |> Enum.uniq_by(&elem(&1, 1))
    |> Enum.map(fn {probability, word} ->
      %{word: word, probability: probability, percent: bar_height(probability, peak)}
    end)
  end

  defp heatmap_rows(values, labels, highlight, scale) do
    lit_rows = highlight |> Enum.map(&elem(&1, 0)) |> MapSet.new()

    values
    |> Enum.zip(labels)
    |> Enum.with_index()
    |> Enum.map(fn {{row_values, label}, row} ->
      %{
        label: label,
        lit?: MapSet.member?(lit_rows, row),
        cells: heatmap_cells(row_values, label, row, highlight, scale)
      }
    end)
  end

  defp heatmap_cells(row_values, row_label, row, highlight, scale) do
    row_values
    |> Enum.with_index()
    |> Enum.map(fn {value, column} ->
      %{
        value: value,
        intensity: intensity(value, scale),
        lit?: {row, column} in highlight,
        title: "#{row_label} -> #{format_weight(value)}"
      }
    end)
  end

  # A square root ramp so the small-but-not-zero cells are visible at all. The
  # ordering is untouched, which is the only thing a sequential scale promises.
  defp intensity(value, :sqrt), do: value |> max(0.0) |> :math.sqrt() |> Float.round(3)
  defp intensity(value, :linear), do: value |> max(0.0) |> min(1.0) |> Float.round(3)

  defp format_weight(value), do: :erlang.float_to_binary(value * 1.0, decimals: 2)

  defp format_signed(value) when value < 0, do: "\u2212" <> format_weight(-value)
  defp format_signed(value), do: format_weight(value)

  defp format_percent(value), do: "#{:erlang.float_to_binary(value * 100, decimals: 1)}%"

  defp loss_chart_scale(assigns) do
    last = assigns.losses |> Enum.map(&elem(&1, 0)) |> Enum.max(fn -> 1 end)

    Chart.new(
      width: assigns.width,
      height: assigns.height,
      x_domain: {0, max(assigns.steps || last, 1)},
      y_domain: {1.5, ceil_to(assigns.knowing_nothing)}
    )
  end

  defp ceil_to(value), do: Float.ceil(value * 2) / 2
end
