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

  describe "steps/1" do
    test "gives a stub one beat, however many the arc plans for" do
      stub = Enum.find(Deck.slides(), &(&1.steps > 1 and not SlideComponents.drawn?(&1.id)))

      assert stub.steps > 1
      assert SlideComponents.steps(stub.index) == 1
    end

    test "gives a drawn slide the beats the arc plans for" do
      drawn = Enum.find(Deck.slides(), &(&1.steps > 1 and SlideComponents.drawn?(&1.id)))

      assert SlideComponents.steps(drawn.index) == drawn.steps
    end
  end
end
