defmodule VideoConference.StreamServerAdminPortal.EventStore.ListenerTest do
  use ExUnit.Case, async: true

  alias VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyWasAdded
  alias VideoConference.StreamServerAdminPortal.EventStore.Listener

  defmodule DeclaredListener do
    use Listener,
      name: "declared-listener",
      description: "subscribes to public key events",
      events: [StreamServerPublicKeyWasAdded],
      retries: 2,
      backoff: 10,
      max_backoff: 100

    @impl true
    def handle_event(_event), do: :ok
  end

  describe "use EventStore.Listener" do
    test "__listener__/0 returns the declared options" do
      assert DeclaredListener.__listener__() == %{
               name: "declared-listener",
               description: "subscribes to public key events",
               events: [inspect(StreamServerPublicKeyWasAdded)],
               retries: 2,
               backoff: 10,
               max_backoff: 100
             }
    end

    test "applies default retry and backoff options" do
      defmodule DefaultsListener do
        use Listener,
          name: "defaults-listener",
          events: [StreamServerPublicKeyWasAdded]

        @impl true
        def handle_event(_event), do: :ok
      end

      assert DefaultsListener.__listener__() == %{
               name: "defaults-listener",
               description: "",
               events: [inspect(StreamServerPublicKeyWasAdded)],
               retries: 5,
               backoff: 500,
               max_backoff: 30_000
             }
    end

    test "raises a compile-time error when :name is missing" do
      assert_raise ArgumentError, ~r/non-empty :name/, fn ->
        defmodule NamelessListener do
          use Listener, events: [StreamServerPublicKeyWasAdded]

          def handle_event(_event), do: :ok
        end
      end
    end

    test "raises a compile-time error when :name is empty" do
      assert_raise ArgumentError, ~r/non-empty :name/, fn ->
        defmodule EmptyNameListener do
          use Listener, name: "", events: [StreamServerPublicKeyWasAdded]

          def handle_event(_event), do: :ok
        end
      end
    end

    test "raises a compile-time error when :events is missing" do
      assert_raise ArgumentError, ~r/:events/, fn ->
        defmodule EventlessListener do
          use Listener, name: "eventless-listener"

          def handle_event(_event), do: :ok
        end
      end
    end

    test "raises a compile-time error when :events is empty" do
      assert_raise ArgumentError, ~r/:events/, fn ->
        defmodule EmptyEventsListener do
          use Listener, name: "empty-events-listener", events: []

          def handle_event(_event), do: :ok
        end
      end
    end
  end
end
