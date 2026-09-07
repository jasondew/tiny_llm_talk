defmodule TinyLlmTalk.CodeTest do
  use ExUnit.Case, async: true

  alias TinyLlmTalk.Code

  @source """
  def forward(params, input_ids) do
    input_ids
    |> embed(params)
    |> Block.forward(params)
  end
  """

  test "returns one fragment per line of source" do
    assert length(Code.lines(@source)) == 5
  end

  test "keeps a line's own indentation" do
    [_first, second | _rest] = Code.lines(@source)

    assert Phoenix.HTML.safe_to_string(second) =~ "  "
  end

  test "highlights, rather than escaping into nothing" do
    [first | _rest] = Code.lines(@source)

    assert Phoenix.HTML.safe_to_string(first) =~ ~s(<span class=")
    assert Phoenix.HTML.safe_to_string(first) =~ "forward"
  end

  describe "font_size/2" do
    test "shrinks a listing with a long line so it fits the stage" do
      assert Code.font_size(3, 30) == 24.0
      assert Code.font_size(3, 100) < 20.0
      assert Code.longest_line("short\na much longer line here") == 23
    end
  end

  describe "elide/2" do
    test "folds the lines into one unnumbered row and keeps the numbers either side" do
      rows = @source |> Code.focused([], 1) |> Code.elide(2..4)

      assert Enum.map(rows, & &1.number) == [1, nil, 5]
    end

    test "leaves the rows alone with nothing to fold" do
      rows = Code.focused(@source, [], 1)

      assert Code.elide(rows, nil) == rows
    end
  end

  describe "font_size/3" do
    test "shrinks further when the listing has less of the stage" do
      assert Code.font_size(5, 90, 500) < Code.font_size(5, 90)
    end
  end

  describe "focused/3" do
    test "lights every line when a step has no window" do
      rows = Code.focused(@source, [], 1)

      assert Enum.all?(rows, & &1.lit?)
    end

    test "dims everything outside the step's window" do
      rows = Code.focused(@source, [:all, 2..3], 2)

      assert Enum.filter(rows, & &1.lit?) |> Enum.map(& &1.number) == [2, 3]
    end

    test "accepts several windows in one step" do
      rows = Code.focused(@source, [[1..1, 4..4]], 1)

      assert Enum.filter(rows, & &1.lit?) |> Enum.map(& &1.number) == [1, 4]
    end
  end
end
