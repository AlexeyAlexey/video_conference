defmodule VideoConferenceWeb.AdminPortal.DropdownComponentTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias VideoConferenceWeb.AdminPortal.DropdownComponent

  defmodule HostLive do
    use VideoConferenceWeb, :live_view

    alias VideoConferenceWeb.AdminPortal.DropdownComponent

    @options [{"Alpha", "a"}, {"Beta", "b"}, {"Gamma", "g"}]

    def fun_options(query) do
      query = String.downcase(query)

      Enum.filter(
        [{"Zulu", "z"}, {"Yankee", "y"}, {"Xray", "x"}],
        fn {label, _value} -> String.contains?(String.downcase(label), query) end
      )
    end

    def mount(_params, session, socket) do
      options = if session["fun_options"], do: &fun_options/1, else: @options

      {:ok,
       assign(socket,
         form: to_form(cast(%{"choice" => session["initial"]}), as: :dropdown),
         options: options,
         label: session["label"] || "Choice",
         placeholder: session["placeholder"] || "Choose one",
         empty_label: session["empty_label"],
         searchable: session["searchable"] || false,
         value_key: session["value_key"] || "value"
       )}
    end

    def render(assigns) do
      ~H"""
      <.form for={@form} id="host-form" phx-change="validate">
        <.live_component
          module={DropdownComponent}
          id="choice"
          label={@label}
          field={@form[:choice]}
          options={@options}
          placeholder={@placeholder}
          empty_label={@empty_label}
          searchable={@searchable}
          search_placeholder="Type to filter"
          value_key={@value_key}
          on_change={fn value -> send(self(), {:picked, value}) end}
        />
      </.form>
      <button id="force-close" phx-click="close" phx-target="#choice-field">close</button>
      """
    end

    def handle_event("validate", %{"dropdown" => params}, socket) do
      changeset =
        params
        |> cast()
        |> Ecto.Changeset.validate_required(:choice)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, form: to_form(changeset, as: :dropdown))}
    end

    def handle_info({:picked, value}, socket) do
      changeset =
        socket.assigns.form.source
        |> Ecto.Changeset.put_change(:choice, value)
        |> Map.update!(:errors, &Keyword.delete(&1, :choice))

      {:noreply, assign(socket, form: to_form(changeset, as: :dropdown))}
    end

    defp cast(params) do
      Ecto.Changeset.cast({%{}, %{choice: :string}}, params, [:choice])
    end
  end

  defp mount_dropdown(conn, session \\ %{}) do
    {:ok, lv, html} = live_isolated(conn, HostLive, session: session)
    {lv, html}
  end

  test "closed dropdown shows the placeholder and no listbox", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn)

    assert has_element?(lv, "#choice-dropdown-button", "Choose one")
    assert has_element?(lv, ~s|#choice-dropdown-button[aria-haspopup="listbox"]|)
    assert has_element?(lv, ~s|#choice-dropdown-button[aria-expanded="false"]|)
    refute has_element?(lv, "#choice-dropdown")
  end

  test "closed dropdown shows the selected option's label", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn, %{"initial" => "b"})

    assert has_element?(lv, "#choice-dropdown-button", "Beta")
  end

  test "never renders a native select", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn)

    refute has_element?(lv, "select")
  end

  test "button toggles the listbox open and closed", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn)

    lv |> element("#choice-dropdown-button") |> render_click()

    assert has_element?(lv, ~s|#choice-dropdown[role="listbox"]|)
    assert has_element?(lv, ~s|#choice-dropdown-button[aria-expanded="true"]|)
    assert has_element?(lv, ~s|#choice-dropdown [role="option"]|, "Alpha")

    lv |> element("#choice-dropdown-button") |> render_click()

    refute has_element?(lv, "#choice-dropdown")
  end

  test "click-away binding closes the dropdown without changing the value", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn, %{"initial" => "a"})

    assert has_element?(lv, ~s|[phx-click-away="close"]|)

    lv |> element("#choice-dropdown-button") |> render_click()
    assert has_element?(lv, "#choice-dropdown")

    lv |> element("#force-close") |> render_click()

    refute has_element?(lv, "#choice-dropdown")
    assert has_element?(lv, ~s|input[name="dropdown[choice]"][value="a"]|)
  end

  test "pick invokes the on_change callback and closes the listbox", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn)

    lv |> element("#choice-dropdown-button") |> render_click()

    lv
    |> element(~s|#choice-dropdown button[phx-value-value="b"]|)
    |> render_click()

    refute has_element?(lv, "#choice-dropdown")
    assert has_element?(lv, ~s|input[name="dropdown[choice]"][value="b"]|)
    assert has_element?(lv, "#choice-dropdown-button", "Beta")
  end

  test "option buttons carry the configured value_key", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn, %{"value_key" => "code"})

    lv |> element("#choice-dropdown-button") |> render_click()

    lv
    |> element(~s|#choice-dropdown button[phx-value-code="a"]|)
    |> render_click()

    assert has_element?(lv, ~s|input[name="dropdown[choice]"][value="a"]|)
  end

  test "marks the selected option with aria-selected and highlight", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn, %{"initial" => "b"})

    lv |> element("#choice-dropdown-button") |> render_click()

    assert has_element?(
             lv,
             ~s|#choice-dropdown button[aria-selected="true"][role="option"]|,
             "Beta"
           )

    assert has_element?(
             lv,
             ~s|#choice-dropdown button[aria-selected="true"].font-semibold|
           )

    assert has_element?(
             lv,
             ~s|#choice-dropdown button[aria-selected="false"]|,
             "Alpha"
           )
  end

  test "renders a hidden input bound to the field inside the form", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn, %{"initial" => "a"})

    assert has_element?(
             lv,
             ~s|#host-form input[type="hidden"][name="dropdown[choice]"][value="a"]|
           )
  end

  test "picked value submits through the form's normal flow", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn)

    lv |> element("#choice-dropdown-button") |> render_click()

    lv
    |> element(~s|#choice-dropdown button[phx-value-value="g"]|)
    |> render_click()

    # the hidden input value is part of the submitted params
    lv
    |> form("#host-form", dropdown: %{"choice" => "g"})
    |> render_change()

    assert has_element?(lv, ~s|input[name="dropdown[choice]"][value="g"]|)
  end

  test "shows a validation error inline once the field was used", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn)

    lv |> form("#host-form", dropdown: %{"choice" => ""}) |> render_change()

    assert has_element?(lv, "#choice-field p.text-error", "can't be blank")

    lv |> element("#choice-dropdown-button") |> render_click()

    lv
    |> element(~s|#choice-dropdown button[phx-value-value="a"]|)
    |> render_click()

    refute has_element?(lv, "#choice-field p.text-error")
    assert has_element?(lv, "#choice-dropdown-button", "Alpha")
  end

  test "search filters list options by label", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn, %{"searchable" => true})

    lv |> element("#choice-dropdown-button") |> render_click()
    assert has_element?(lv, "#choice-search")

    lv |> element("#choice-search") |> render_change(%{"choice_search" => "bet"})

    assert has_element?(lv, ~s|#choice-dropdown button[phx-value-value="b"]|)
    refute has_element?(lv, ~s|#choice-dropdown button[phx-value-value="a"]|)
    refute has_element?(lv, ~s|#choice-dropdown button[phx-value-value="g"]|)
  end

  test "search delegates filtering to an options function", %{conn: conn} do
    {lv, _html} =
      mount_dropdown(conn, %{"fun_options" => true, "searchable" => true})

    lv |> element("#choice-dropdown-button") |> render_click()

    assert has_element?(lv, ~s|#choice-dropdown button[phx-value-value="z"]|)
    refute has_element?(lv, ~s|#choice-dropdown button[phx-value-value="a"]|)

    lv |> element("#choice-search") |> render_change(%{"choice_search" => "xra"})

    assert has_element?(lv, ~s|#choice-dropdown button[phx-value-value="x"]|)
    refute has_element?(lv, ~s|#choice-dropdown button[phx-value-value="z"]|)
  end

  test "reopening resets the search query", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn, %{"searchable" => true})

    lv |> element("#choice-dropdown-button") |> render_click()
    lv |> element("#choice-search") |> render_change(%{"choice_search" => "bet"})

    refute has_element?(lv, ~s|#choice-dropdown button[phx-value-value="a"]|)

    lv |> element("#choice-dropdown-button") |> render_click()
    lv |> element("#choice-dropdown-button") |> render_click()

    assert has_element?(lv, ~s|#choice-dropdown button[phx-value-value="a"]|)
  end

  test "empty_label renders an empty choice that clears the value", %{conn: conn} do
    {lv, _html} =
      mount_dropdown(conn, %{"initial" => "b", "empty_label" => "None"})

    lv |> element("#choice-dropdown-button") |> render_click()

    assert has_element?(lv, ~s|#choice-option-none[role="option"]|, "None")

    lv
    |> element(~s|#choice-option-none|)
    |> render_click()

    assert has_element?(lv, ~s|input[name="dropdown[choice]"][value=""]|)
    assert has_element?(lv, "#choice-dropdown-button", "None")
    refute has_element?(lv, "#choice-dropdown")
  end

  test "empty choice is marked selected while the value is empty", %{conn: conn} do
    {lv, _html} = mount_dropdown(conn, %{"empty_label" => "None"})

    lv |> element("#choice-dropdown-button") |> render_click()

    assert has_element?(lv, ~s|#choice-option-none[aria-selected="true"]|)
  end
end
