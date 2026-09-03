defmodule TinyLlmTalk.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TinyLlmTalkWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:tiny_llm_talk, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TinyLlmTalk.PubSub},
      {Task.Supervisor, name: TinyLlmTalk.TaskSupervisor},
      TinyLlmTalk.Model,
      TinyLlmTalk.Room,
      TinyLlmTalk.Trainer,
      # Start to serve requests, typically the last entry
      TinyLlmTalkWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TinyLlmTalk.Supervisor]
    started = Supervisor.start_link(children, opts)

    warm_the_figures()

    started
  end

  # Counting two thousand sentences takes a moment. Pay for it at boot, in an
  # empty room, rather than on the first slide that shows a heatmap.
  defp warm_the_figures do
    Task.start(fn ->
      TinyLlmTalk.Model.bigram()
      TinyLlmTalk.Model.bigram_floor()
      TinyLlmTalk.Model.trace(TinyLlmTalk.Model.probe())
      TinyLlmTalk.Model.trace(TinyLlmTalk.Model.mirror_probe())
      TinyLlmTalk.Model.trace(TinyLlmTalk.Model.rematch_probe())
      Enum.each([:bigram, :transformer], &TinyLlmTalk.Model.agreement/1)
      TinyLlmTalk.Model.lineup()
      TinyLlmTalk.Room.activities()
      TinyLlmTalk.Writer.paragraph(TinyLlmTalk.Writer.seed(0))
    end)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TinyLlmTalkWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
