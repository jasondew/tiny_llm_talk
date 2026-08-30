defmodule TinyLlmTalkWeb.FigureComponents do
  @moduledoc """
  The pictures: heatmaps, distributions, loss curves, the scatter, and the box
  the whole talk keeps coming back to.

  Every one of these is handed plain Elixir terms straight out of
  `TinyLlmTalk.Model`, which is the reason the deck is a Phoenix app. There is
  no export step and no image to go stale; a figure is the model's own numbers,
  rendered.

  Colour follows the job. Magnitude gets one hue, light to dark, so a heatmap
  reads as more and less rather than as a rainbow. Identity gets the fixed
  categorical order in `deck.css`, assigned in order and never cycled.
  """

  use Phoenix.Component

  alias TinyLlmTalk.Chart

  @doc """
  The recurring figure: words in, a box, and 32 probabilities out.

  It appears once per model with a different label inside the box, which is the
  spine of the arc. Same function, more context each time.
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
  attr :class, :string, default: nil

  def bars(assigns) do
    assigns = assign(assigns, rows: top_rows(assigns.values, assigns.words, assigns.top))

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
  """
  attr :losses, :list, required: true
  attr :knowing_nothing, :float, required: true
  attr :floor, :float, required: true
  attr :floor_label, :string, default: "one-word floor"
  attr :series_label, :string, default: "held-out loss"
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

        <polyline class="chart__line" points={Chart.polyline(@chart, @losses)} />
      </svg>
      <figcaption class="chart__caption">{@series_label}, against training step</figcaption>
    </figure>
    """
  end

  @doc """
  The learned embeddings, flattened onto their two strongest directions.

  Coloured by part of speech and direct-labelled, so identity never rests on
  colour alone.
  """
  attr :points, :list, required: true
  attr :width, :integer, default: 880
  attr :height, :integer, default: 440
  attr :labels, :boolean, default: true

  def scatter(assigns) do
    assigns = assign(assigns, chart: scatter_scale(assigns))

    ~H"""
    <figure class="chart">
      <svg
        viewBox={"0 0 #{@width} #{@height}"}
        class="chart__svg"
        role="img"
        aria-label="learned embeddings, projected onto two dimensions"
      >
        <g :for={point <- @points} class={"scatter scatter--#{point.kind}"}>
          <circle cx={Chart.x(@chart, point.x)} cy={Chart.y(@chart, point.y)} r="7" />
          <text :if={@labels} x={Chart.x(@chart, point.x) + 12} y={Chart.y(@chart, point.y) + 4}>
            {point.word}
          </text>
        </g>
      </svg>
      <figcaption class="chart__legend">
        <span
          :for={kind <- ~w(noun verb adjective determiner connective boundary)a}
          class={"chart__legend-item scatter--#{kind}"}
        >
          <span class="chart__swatch" />{kind}
        </span>
      </figcaption>
    </figure>
    """
  end

  @doc """
  Two measures of the same kind, on one axis, as temperature rises.

  Both are percentages, so they share a scale honestly. Two series get a
  legend, and each is direct-labelled at its end.
  """
  attr :curve, :list, required: true
  attr :width, :integer, default: 900
  attr :height, :integer, default: 400

  def tradeoff_chart(assigns) do
    assigns =
      assign(assigns,
        chart:
          Chart.new(
            width: assigns.width,
            height: assigns.height,
            x_domain: {0.0, 3.0},
            y_domain: {0.0, 1.0}
          ),
        grammatical: Enum.map(assigns.curve, &{&1.temperature, &1.grammatical}),
        distinct: Enum.map(assigns.curve, &{&1.temperature, &1.distinct})
      )

    ~H"""
    <figure class="chart">
      <svg
        viewBox={"0 0 #{@width} #{@height}"}
        class="chart__svg"
        role="img"
        aria-label="grammaticality and distinctness against temperature"
      >
        <line
          :for={value <- Chart.ticks({0.0, 1.0}, 5)}
          class="chart__grid"
          x1={Chart.x(@chart, 0.0)}
          x2={Chart.x(@chart, 3.0)}
          y1={Chart.y(@chart, value)}
          y2={Chart.y(@chart, value)}
        />
        <text
          :for={value <- Chart.ticks({0.0, 1.0}, 5)}
          class="chart__tick"
          x={Chart.x(@chart, 0.0) - 12}
          y={Chart.y(@chart, value) + 5}
          text-anchor="end"
        >
          {round(value * 100)}%
        </text>
        <text
          :for={value <- Chart.ticks({0.0, 3.0}, 7)}
          class="chart__tick"
          x={Chart.x(@chart, value)}
          y={@height - 14}
          text-anchor="middle"
        >
          {:erlang.float_to_binary(value, decimals: 1)}
        </text>

        <polyline
          class="chart__line chart__line--series-1"
          points={Chart.polyline(@chart, @grammatical)}
        />
        <polyline
          class="chart__line chart__line--series-2"
          points={Chart.polyline(@chart, @distinct)}
        />
      </svg>
      <figcaption class="chart__legend">
        <span class="chart__legend-item chart__legend-item--series-1">
          <span class="chart__swatch" />grammatical
        </span>
        <span class="chart__legend-item chart__legend-item--series-2">
          <span class="chart__swatch" />distinct
        </span>
        <span class="chart__legend-note">temperature &rarr;</span>
      </figcaption>
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

  defp top_rows(values, words, count) do
    peak = Enum.max(values)

    values
    |> Enum.zip(words)
    |> Enum.sort_by(fn {probability, _word} -> -probability end)
    |> Enum.take(count)
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

  defp format_percent(value), do: "#{:erlang.float_to_binary(value * 100, decimals: 1)}%"

  defp loss_chart_scale(assigns) do
    steps = Enum.map(assigns.losses, &elem(&1, 0))

    Chart.new(
      width: assigns.width,
      height: assigns.height,
      x_domain: {0, Enum.max(steps)},
      y_domain: {1.5, ceil_to(assigns.knowing_nothing)}
    )
  end

  defp scatter_scale(assigns) do
    xs = Enum.map(assigns.points, & &1.x)
    ys = Enum.map(assigns.points, & &1.y)

    Chart.new(
      width: assigns.width,
      height: assigns.height,
      x_domain: {Enum.min(xs), Enum.max(xs)},
      y_domain: {Enum.min(ys), Enum.max(ys)},
      padding: %{top: 24, right: 90, bottom: 24, left: 24}
    )
  end

  defp ceil_to(value), do: Float.ceil(value * 2) / 2
end
