defmodule TinyLlmTalkWeb.SlideComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias TinyLlmTalk.Deck
  alias TinyLlmTalkWeb.SlideComponents

  describe "drawn?/1" do
    test "agrees with the clauses that actually exist" do
      for slide <- Deck.slides() do
        html = render_component(&SlideComponents.slide/1, slide: slide, step: 1)
        stub? = html =~ "not drawn yet"

        assert stub? != SlideComponents.drawn?(slide.id),
               "#{slide.id} is #{if stub?, do: "a stub", else: "drawn"} but @drawn says otherwise"
      end
    end
  end

  describe "the writer" do
    test "shows the full stop as a chip once it is picked" do
      slide = Enum.find(Deck.slides(), &(&1.id == :it_writes))
      [first | _rest] = TinyLlmTalk.Writer.paragraph(TinyLlmTalk.Writer.seed(0))
      last_pick = length(first) * length(TinyLlmTalk.Writer.phases()) - 1

      html = render_component(&SlideComponents.slide/1, slide: slide, step: 1, frame: last_pick)

      assert html =~ ~s(<span class="writer__chip-word">.</span>)

      assert html =~
               ~r/writer__chip writer__chip--lit[^>]*>\s*<span class="writer__chip-word">\.</
    end
  end

  describe "steps/1" do
    test "gives a drawn slide its planned beats and a stub exactly one" do
      for slide <- Deck.slides() do
        planned = if SlideComponents.drawn?(slide.id), do: slide.steps, else: 1

        assert SlideComponents.steps(slide.index) == planned,
               "#{slide.id} navigates in #{SlideComponents.steps(slide.index)} steps, not #{planned}"
      end
    end

    test "walks the deck in as many presses as the drawn slides ask for" do
      presses = Deck.slides() |> Enum.map(&SlideComponents.steps(&1.index)) |> Enum.sum()

      assert presses >= Deck.count()
    end
  end
end
