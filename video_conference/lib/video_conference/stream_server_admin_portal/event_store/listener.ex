defmodule VideoConference.StreamServerAdminPortal.EventStore.Listener do
  @moduledoc """
  Behaviour and `use` macro for stream server admin portal event store
  listeners.

  A listener subscribes to an explicit list of event modules and
  receives each matching stored event's decoded struct through
  `c:handle_event/1`, in ascending `seq` order:

      defmodule MyListener do
        use VideoConference.StreamServerAdminPortal.EventStore.Listener,
          name: "my-listener",
          description: "keeps a projection up to date",
          events: [
            VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyWasAdded
          ],
          retries: 5,
          backoff: 500,
          max_backoff: 30_000

        @impl true
        def handle_event(%StreamServerPublicKeyWasAdded{} = event) do
          # ...
          :ok
        end
      end

  Options:

    * `:name` - unique non-empty identity of the listener (required)
    * `:description` - human-readable purpose (default `""`)
    * `:events` - non-empty list of event modules to subscribe to (required)
    * `:retries` - how many times a failed event is retried before the
      listener is marked `failed` (default `5`; `0` fails on the first
      error)
    * `:backoff` - milliseconds to wait before the first retry, doubled
      on each subsequent failure (default `500`)
    * `:max_backoff` - cap for the backoff delay in milliseconds
      (default `30_000`)

  Delivery is **at-least-once**: an event whose `handle_event/1` call
  succeeded but whose cursor write was lost is delivered again, so
  handlers must be idempotent. When the retry budget is exhausted the
  listener is durably marked `failed` and stops until resumed through
  `EventStore.resume_listener/1`.
  """

  @doc """
  Handles a single decoded event struct.

  Return `:ok` to acknowledge the event and advance the durable cursor,
  or `{:error, reason}` to trigger the configured retry policy. Raised
  exceptions are rescued and treated exactly like an error return.
  """
  @callback handle_event(event :: struct()) :: :ok | {:error, term()}

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour VideoConference.StreamServerAdminPortal.EventStore.Listener

      @event_store_listener_config VideoConference.StreamServerAdminPortal.EventStore.Listener.__config__(
                                     opts
                                   )

      @doc false
      def __listener__, do: @event_store_listener_config
    end
  end

  @doc false
  def __config__(opts) when is_list(opts) do
    name = Keyword.get(opts, :name)
    events = Keyword.get(opts, :events)

    unless is_binary(name) and name != "" do
      raise ArgumentError,
            "expected `use #{inspect(__MODULE__)}` to declare a non-empty :name option"
    end

    unless is_list(events) and events != [] and Enum.all?(events, &is_atom/1) do
      raise ArgumentError,
            "expected `use #{inspect(__MODULE__)}` to declare a non-empty :events list of event modules"
    end

    %{
      name: name,
      description: Keyword.get(opts, :description, ""),
      events: Enum.map(events, &inspect/1),
      retries: Keyword.get(opts, :retries, 5),
      backoff: Keyword.get(opts, :backoff, 500),
      max_backoff: Keyword.get(opts, :max_backoff, 30_000)
    }
  end
end
