defmodule TinyLlmTalk.Chart do
  @moduledoc """
  Turning numbers into SVG coordinates.

  A chart is a box, two domains, and the arithmetic between them. Keeping that
  arithmetic here rather than in a template means it can be tested, and means a
  slide says `Chart.y(chart, loss)` instead of doing algebra in a `~H` sigil.

  The stage is 1280 by 720, so charts are authored in stage pixels and need no
  responsive behaviour at all.
  """

  @enforce_keys [:width, :height, :x_domain, :y_domain]
  defstruct [
    :width,
    :height,
    :x_domain,
    :y_domain,
    padding: %{top: 20, right: 24, bottom: 44, left: 64}
  ]

  @type t :: %__MODULE__{}

  @spec new(keyword()) :: t()
  def new(options) do
    struct!(__MODULE__, options)
  end

  @doc "Where a value on the horizontal domain lands, in SVG units."
  @spec x(t(), number()) :: float()
  def x(chart, value) do
    {low, high} = chart.x_domain
    left = chart.padding.left
    span = chart.width - left - chart.padding.right

    left + fraction(value, low, high) * span
  end

  @doc "Where a value on the vertical domain lands. SVG counts down, so this flips."
  @spec y(t(), number()) :: float()
  def y(chart, value) do
    {low, high} = chart.y_domain
    top = chart.padding.top
    span = chart.height - top - chart.padding.bottom

    top + (1.0 - fraction(value, low, high)) * span
  end

  @doc "`points` for an SVG polyline, from `{x, y}` pairs in domain units."
  @spec polyline(t(), [{number(), number()}]) :: String.t()
  def polyline(chart, points) do
    Enum.map_join(points, " ", fn {x, y} -> "#{x(chart, x)},#{y(chart, y)}" end)
  end

  @doc "Evenly spaced values across a domain, inclusive of both ends."
  @spec ticks({number(), number()}, pos_integer()) :: [float()]
  def ticks({low, high}, count) do
    step = (high - low) / (count - 1)

    Enum.map(0..(count - 1)//1, fn index -> low + index * step end)
  end

  @doc "The plotting area, for a background rect or a clip."
  @spec plot(t()) :: %{x: number(), y: number(), width: number(), height: number()}
  def plot(chart) do
    %{
      x: chart.padding.left,
      y: chart.padding.top,
      width: chart.width - chart.padding.left - chart.padding.right,
      height: chart.height - chart.padding.top - chart.padding.bottom
    }
  end

  ## PRIVATE FUNCTIONS

  defp fraction(_value, low, high) when low == high, do: 0.5
  defp fraction(value, low, high), do: (value - low) / (high - low)
end
