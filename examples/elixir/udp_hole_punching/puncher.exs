defmodule Puncher do
  use Ockam.Worker

  require Logger

  alias Ockam.{Message, Router}

  @rendezvous_node "rendezvous"

  @impl true
  def handle_call(:ping_rendezvous_server, _, state) do
    Ockam.Router.route(%{
      payload: "ping",
      onward_route: [state.attributes.rendezvous_address, @rendezvous_node],
      return_route: [state.address]
    })

    {:reply, :ok, state}
  end

  @impl true
  def handle_message(%{payload: "pong"} = message, state) do
    Logger.info("Rendezvous server is up, request address")

    Router.route(%{
      payload: "my address",
      onward_route: [state.attributes.rendezvous_address, @rendezvous_node],
      return_route: [state.address]
    })

    {:ok, state}
  end

  def handle_message(%{payload: "address: " <> address} = message, state) do
    Logger.info("Received address: #{inspect(address)}")

    state = put_in(state, [:attributes, :external_address], address)

    Router.route(%{
      payload: "connect",
      onward_route: [
        state.attributes.rendezvous_address,
        @rendezvous_node,
        state.attributes.target
      ],
      return_route: [state.address]
    })

    {:ok, state}
  end

  def handle_message(%{payload: "connected"} = message, state) do
    Logger.info("Received connected message")

    Router.route(%{
      payload: "hello",
      onward_route: message.return_route |> tl(),
      return_route: [state.attributes.external_address, state.address]
    })

    {:ok, state}
  end

  def handle_message(%{payload: "hello"} = message, state) do
    Logger.info("Received hello message! Hole punching successful!")

    Router.route(Message.reply(message, state.attributes.external_address, "hello"))

    {:ok, state}
  end

  def handle_message(message, %{address: address} = state) do
    Logger.warning("Unknown puncher message #{inspect(message)}}")

    {:ok, state}
  end
end
