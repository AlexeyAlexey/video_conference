defmodule VideoConferenceWeb.StreamServerAdminPortal.ApplicationStreamServersLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.Application
  alias VideoConference.StreamServerAdminPortal.StreamServers
  alias VideoConference.StreamServers.Countries
  alias VideoConferenceWeb.DropdownComponent

  @per_page 20

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Stream Servers")}
  end

  def handle_params(params, _uri, socket) do
    application = application(params["application_id"])
    total_pages = total_pages(application)
    page = min(parse_page(params["page"]), total_pages)

    socket =
      socket
      |> assign(:application, application)
      |> assign(
        :filter_form,
        to_form(%{"application_id" => selected_id(application)}, as: :filter)
      )
      |> assign(:page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:stream_servers, stream_servers(application, page))

    {:noreply, socket}
  end

  defp application(id) when id in [nil, ""], do: nil
  defp application(id), do: Applications.get_application!(id)

  defp selected_id(nil), do: ""
  defp selected_id(%Application{} = application), do: application.id

  defp parse_page(raw) do
    case Integer.parse(raw || "") do
      {page, ""} when page > 0 -> page
      _ -> 1
    end
  end

  defp total_pages(nil), do: 1

  defp total_pages(%Application{} = application),
    do:
      application.id
      |> then(&StreamServers.count_stream_servers(application_id: &1))
      |> then(&max(ceil(&1 / @per_page), 1))

  defp stream_servers(nil, _page), do: []

  defp stream_servers(%Application{} = application, page),
    do:
      StreamServers.list_stream_servers(
        application_id: application.id,
        page: page,
        per_page: @per_page
      )

  def handle_info({:filter_picked, application_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(application_id))}
  end

  defp index_path(application_id, page \\ 1)

  defp index_path(application_id, _page) when application_id in [nil, ""],
    do: "/stream-server-admin/applications/stream-servers"

  defp index_path(application_id, page) when page in [nil, "", 1],
    do: "/stream-server-admin/applications/stream-servers?application_id=#{application_id}"

  defp index_path(application_id, page),
    do:
      "/stream-server-admin/applications/stream-servers?application_id=#{application_id}&page=#{page}"

  defp application_options(query) do
    for application <- Applications.list_applications(search: query),
        do: {application.name, application.id}
  end

  defp description_long?(description) when is_binary(description),
    do: String.length(description) > 50

  defp description_long?(_description), do: false

  defp truncated_description(description) when is_binary(description),
    do: String.slice(description, 0, 50) <> "..."

  def render(assigns) do
    ~H"""
    <Layouts.stream_server_admin
      flash={@flash}
      current_scope={@current_scope}
      admin_sidebar_collapsed={@admin_sidebar_collapsed}
    >
      <div class="mx-auto w-full px-2 sm:px-0">
        <.header>
          Stream Servers
          <:subtitle>Stream servers assigned to each application</:subtitle>
        </.header>

        <p id="servers-description" class="mb-6 text-sm opacity-70">
          Each stream server below is assigned to the selected application and
          carries its streams. Server assignments are managed on the stream
          servers page.
        </p>

        <div class="mb-4 max-w-xs">
          <.form
            for={@filter_form}
            id="application-filter-form"
            onsubmit="event.preventDefault()"
          >
            <.live_component
              module={DropdownComponent}
              id="application-filter"
              label="Application"
              field={@filter_form[:application_id]}
              options={&application_options/1}
              placeholder="Choose an application"
              searchable
              search_placeholder="Type to filter applications"
              value_key="id"
              on_change={fn id -> send(self(), {:filter_picked, id}) end}
            />
          </.form>
        </div>

        <p :if={@application == nil} id="select-application-prompt" class="py-8 text-center">
          Select an application to list its stream servers
        </p>

        <div :if={@application} id="stream-servers-section">
          <p :if={@stream_servers == []} id="no-stream-servers" class="py-8 text-center">
            No stream servers assigned
          </p>
          <div :if={@stream_servers != []} class="overflow-x-auto">
            <table id="stream-servers-table" class="table table-sm sm:table-md">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Host</th>
                  <th>Country</th>
                  <th>Description</th>
                  <th>Cert hash</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={server <- @stream_servers} id={"stream-server-row-#{server.id}"}>
                  <td class="whitespace-nowrap">
                    {server.name}
                  </td>
                  <td>{server.host}</td>
                  <td class="whitespace-nowrap">
                    {Countries.flag(server.country)}
                  </td>
                  <td class="max-w-64 break-all">
                    <div class="min-w-0 flex-1">
                      <button
                        :if={description_long?(server.description)}
                        type="button"
                        id={"server-description-#{server.id}"}
                        phx-click={
                          JS.toggle_class("hidden",
                            to: "#server-description-short-#{server.id}"
                          )
                          |> JS.toggle_class("hidden",
                            to: "#server-description-full-#{server.id}"
                          )
                        }
                        class="w-full cursor-pointer text-left"
                        title="Show the full description"
                      >
                        <span
                          id={"server-description-short-#{server.id}"}
                          class="break-all"
                        >
                          {truncated_description(server.description)}
                        </span>
                        <span
                          id={"server-description-full-#{server.id}"}
                          class="hidden whitespace-pre-wrap break-all"
                        >
                          {server.description}
                        </span>
                      </button>
                      <span
                        :if={not description_long?(server.description)}
                        class="break-all"
                      >
                        {server.description}
                      </span>
                    </div>
                  </td>
                  <td id={"cert-hash-#{server.id}"} class="whitespace-nowrap">
                    <%= if server.cert_hash do %>
                      Set
                      <span id={"cert-hash-value-#{server.id}"} class="hidden">
                        {server.cert_hash}
                      </span>
                      <button
                        type="button"
                        id={"copy-cert-hash-#{server.id}"}
                        onclick={"navigator.clipboard.writeText(document.getElementById('cert-hash-value-#{server.id}').textContent.trim())"}
                        class="btn btn-ghost btn-xs"
                        title="Copy certificate hash"
                      >
                        <.icon name="hero-document-duplicate" class="size-4" />
                      </button>
                    <% else %>
                      —
                    <% end %>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div
            :if={@total_pages > 1}
            id="stream-servers-pagination"
            class="mt-4 flex items-center justify-between"
          >
            <p id="page-status" class="text-sm opacity-70">
              Page {@page} of {@total_pages}
            </p>
            <div class="join">
              <%= if @page > 1 do %>
                <.link
                  patch={index_path(@application.id, @page - 1)}
                  id="prev-page"
                  class="join-item btn btn-sm"
                >
                  «
                </.link>
              <% else %>
                <span class="join-item btn btn-sm btn-disabled">«</span>
              <% end %>
              <%= if @page < @total_pages do %>
                <.link
                  patch={index_path(@application.id, @page + 1)}
                  id="next-page"
                  class="join-item btn btn-sm"
                >
                  »
                </.link>
              <% else %>
                <span class="join-item btn btn-sm btn-disabled">»</span>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.stream_server_admin>
    """
  end
end
