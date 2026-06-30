This is a web application written using the Phoenix web framework.

## Project Overview

**App Name:** `video_conference`

This is a video conferencing application that uses **HTTP/3 with WebTransport and WebCodecs** instead of WebRTC for real-time media streaming. The backend is a Phoenix API server, while the frontend handles video/audio encoding/decoding using browser APIs.

### Key Technologies

- **Backend:** Phoenix 1.8 (Elixir), SQLite3 via `ecto_sqlite3`, Bandit HTTP server
- **Frontend:** A standalone application that communicates with the backend via REST APIs and channels, built with vite and vanilla js and Tailwind CSS.
- **Real-time Communication:** HTTP/3 with WebTransport (streams and datagrams)
- **Authentication:** Custom scope-based authentication with phone-based sessions

### Frontend-Backend Communication

The frontend is a standalone application that communicates with the backend via:

1. **REST APIs** - JSON endpoints for user management, phone book, shared links, etc.
   - Public routes: `/phones/register`, `/phones/log-in`, `/conference/public/*`
   - Protected routes: `/phone_book/*`, `/shared_link/*` (require authentication)

2. **Channels** - Real-time communication via Phoenix Channels and HTTP/3 WebTransport
   - PhoneSocket - Phone-based authentication for channels
   - GroupSocket - Room-based channels for video conferencing participants

### Project Structure

```
lib/
├── video_conference/          # Core contexts (business logic)
│   ├── accounts/             # Phone authentication & user management
│   ├── phone_books/          # Contact management
│   ├── shared_links/         # Shared conference link generation
│   └── telephone_switchboard/# Call routing logic
└── video_conference_web/     # Web interface layer
    ├── controllers/          # REST API endpoints (JSON)
    ├── channels/             # WebSocket channels for real-time communication
    ├── components/           # Phoenix components (LiveView, HEEx)
    └── router.ex             # Route definitions

assets/
├── js/                       # Frontend JavaScript (WebCodecs, WebTransport)
│   ├── group_socket.js       # HTTP/3 stream management
│   ├── video_decoder.js      # Video decoding with WebCodecs
│   ├── audio_decoder.js      # Audio decoding with WebCodecs
│   └── current_participant_camera.js # Camera capture & encoding
└── css/                      # Tailwind CSS styles

test/
├── support/
│   ├── conn_case.ex          # Connection test base
│   ├── data_case.ex          # Database test base
│   └── fixtures/             # Test data fixtures
```

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

### Mix Aliases

| Alias | Description |
|-------|-------------|
| `mix setup` | Install deps, create DB, run migrations, seed data, set up assets |
| `mix precommit` | Compile (warnings as errors), unlock unused deps, format code, run tests |
| `mix ecto.setup` | Create DB, run migrations, seed data |
| `mix ecto.reset` | Drop DB and run `ecto.setup` |
| `mix test` | Create DB, run migrations, then run tests |
| `mix assets.setup` | Install Tailwind and ESBuild if missing |
| `mix assets.build` | Build CSS (Tailwind) and JS (ESBuild) |
| `mix assets.deploy` | Minify and deploy assets for production |

### Environment Configuration

- **Database:** SQLite3 (`ecto_sqlite3`)
- **Server:** Bandit (Phoenix adapter)
- **LiveView signing salt:** Configured in `config/config.exs`
- **HTTP/3 Server:** (also known as stream server) External service configured via environment variables:
  - `HTTP3_SERVER_HOST`
  - `HTTP3_SERVER_PORT`
  - `HTTP3_SERVER_CERT_HASH`

### Authentication System

This app uses a custom scope-based authentication system with two pipelines:

| Pipeline | Purpose | Assign Key |
|----------|---------|------------|
| `:browser` | HTML pages | `@current_scope` (phone) |
| `:api` | JSON API | `@current_scope` (phone) |

**Key Authentication Concepts:**
- **Scope:** Contains `current_scope.phone` with the authenticated phone record
- **Token-based:** Auth tokens stored in `AccountAuthToken` and passed via headers/params
- **Phone-based:** Authentication is by phone number, not traditional user accounts

### Routes Organization

#### Public Routes (no auth required)
```elixir
scope "/", VideoConferenceWeb do
  pipe_through :api
  post "/phones/register", PhoneRegistrationController, :register
  post "/phones/log-in", PhoneSessionController, :log_in
  post "/conference/public/shared_link/:link_id", ConferencePublicController, :shared_link
  get "/conference/public/shared_link/info/:link_id", SharedLinkPublicController, :info
end
```

#### Protected Routes (auth required)
```elixir
scope "/", VideoConferenceWeb do
  pipe_through [:api, :require_api_authentication]
  delete "/phones/log-out", PhoneSessionController, :log_out
  post "/phone_book/add_phone", PhoneBookController, :add_phone
  # ... other protected routes
end
```

#### Browser Routes (HTML)
```elixir
scope "/", VideoConferenceWeb do
  pipe_through :browser
  get "/", PageController, :home
end
```

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your custom classes must fully style the input

### Testing Guidelines

#### Test Case Hierarchy
- **`DataCase`** - Base case for database tests (uses SQL sandbox)
- **`ConnCase`** - For controller tests that need connections (extends DataCase)
- **`ChannelCase`** - For Phoenix Channel tests

All test cases use `ExUnit.CaseTemplate` with proper `using/1` and `setup/1` blocks.

#### Fixtures
Test fixtures are located in `test/support/fixtures/`:
- `AccountsFixtures` - Phone account creation helpers
- `PhoneBookFixtures` - Contact management helpers
- `PhoneCallFixtures` - Phone call record helpers
- `SharedLinksFixtures` - Shared link creation helpers

Use fixtures to create test data consistently across tests.

#### Testing Patterns

**Controller Tests:**
```elixir
use VideoConferenceWeb.ConnCase
import VideoConference.AccountsFixtures

test "requires authentication", %{conn: conn} do
  conn = post(conn, ~p"/protected/route")
  assert json_response(conn, 401)
end
```

**Channel Tests:**
```elixir
use VideoConferenceWeb.ChannelCase
import Phoenix.ChannelTest

test "assigns current_scope on connect", %{socket: socket} do
  assert {:ok, _socket} = connect(PhoneSocket, %{}, 
    connect_info: %{auth_token: valid_auth_token(phone)})
end
```

**LiveView Tests:**
- Use `Phoenix.LiveViewTest` module with `LazyHTML` for assertions
- Always reference key element IDs in selectors
- Test outcomes rather than implementation details

#### Database Testing
- SQL sandbox mode for test isolation (automatic)
- Changes automatically rolled back after each test
- Use `Repo.exists?/2` to verify database state

<!-- phoenix-gen-auth-start -->
## Authentication

- **Always** handle authentication flow at the router level with proper redirects
- **Always** be mindful of where to place routes. `phx.gen.auth` creates multiple router plugs:
  - A plug `:fetch_current_scope_for_phone` that is included in the default browser pipeline
  - A plug `:require_authenticated_phone` that redirects to the log in page when the phone is not authenticated
  - In both cases, a `@current_scope` is assigned to the Plug connection
  - A plug `redirect_if_phone_is_authenticated` that redirects to a default path in case the phone is authenticated - useful for a registration page that should only be shown to unauthenticated phones
- **Always let the user know in which router scopes and pipeline you are placing the route, AND SAY WHY**
- `phx.gen.auth` assigns the `current_scope` assign - it **does not assign a `current_phone` assign**
- Always pass the assign `current_scope` to context modules as first argument. When performing queries, use `current_scope.phone` to filter the query results
- To derive/access `current_phone` in templates, **always use the `@current_scope.phone`**, never use **`@current_phone`** in templates
- Anytime you hit `current_scope` errors or the logged in session isn't displaying the right content, **always double check the router and ensure you are using the correct plug as described below**

### Routes that require authentication

Controller routes must be placed in a scope that sets the `:require_authenticated_phone` plug:

    scope "/", AppWeb do
      pipe_through [:api, :require_api_authentication]

      get "/", MyControllerThatRequiresAuth, :index
    end

### Routes that work with or without authentication

Controllers automatically have the `current_scope` available if they use the `:browser` pipeline.

<!-- phoenix-gen-auth-end -->

<!-- usage-rules-start -->
<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason
<!-- phoenix:elixir-end -->
<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->
<!-- phoenix:ecto-start -->
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
<!-- phoenix:ecto-end -->
<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`
- Remember anytime you use `phx-hook="MyHook"` and that js hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Never** write embedded `<script>` tags in HEEx. Instead always write your scripts and hooks in the `assets/js` directory and integrate them with the `assets/js/app.js` file

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
        socket
        |> assign(:messages_empty?, messages == [])
        # reset the stream with the new messages
        |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @stream.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset

### HTTP/3 and WebTransport Guidelines

This app uses **HTTP/3 with WebTransport** instead of WebRTC for real-time media streaming. Key files:

- `assets/js/group_socket.js` - HTTP/3 stream management (connects to external http3_server)
- `assets/js/video_decoder.js` - Video decoding with WebCodecs
- `assets/js/audio_decoder.js` - Audio decoding with WebCodecs
- `assets/js/current_participant_camera.js` - Camera capture & encoding
- `assets/js/http3_stream_message_parser.js` - Message framing for stream data

**Key Concepts:**
- **HTTP/3** uses QUIC protocol over UDP to eliminate head-of-line blocking
- **WebTransport** provides reliable streams and unreliable datagrams
- **WebCodecs** gives low-level access to video/audio frames for full control

**Stream Management:**
- Use `Http3StreamMessageParser` to frame data chunks (see `decodeChunk/1`, `decodeAudioChunk/1`)
- Each chunk needs a header to determine where it begins/ends in the continuous byte stream
- Buffer size: typically 1MB (`1024 * 1024`) for video streams

**Configuration:**
HTTP/3 (stream server) server settings via environment variables:
```elixir
config :video_conference, :stream_server,
    schema: "https",
    host: http3_server_host,
    port: http3_server_port
```

External HTTP/3 server (configured at runtime):
- `HTTP3_SERVER_HOST` - Hostname of the HTTP/3 server
- `HTTP3_SERVER_PORT` - Port (typically 4040)
- `HTTP3_SERVER_CERT_HASH` - Certificate hash for secure connection

**Frontend Integration:**
- Always integrate custom JS hooks in `assets/js/app.js`
- Never write embedded `<script>` tags in HEEx templates
- Use `phx-hook="MyHook"` with `phx-update="ignore"` when hook manages its own DOM

### Custom Authentication System

This app uses a **scope-based authentication system** with phone-based sessions:

#### Authentication Pipelines

| Pipeline | Purpose | Assign Key |
|----------|---------|------------|
| `:browser` | HTML pages | `@current_scope` (phone) |
| `:api` | JSON API | `@current_scope` (phone) |

#### Key Concepts
- **Scope:** Contains `current_scope.phone` with the authenticated phone record
- **Token-based:** Auth tokens stored in `AccountAuthToken` and passed via headers/params
- **Phone-based:** Authentication is by phone number, not traditional user accounts

#### Router Scopes

**Public Routes (no auth required):**
```elixir
scope "/", VideoConferenceWeb do
  pipe_through :api
  post "/phones/register", PhoneRegistrationController, :register
  post "/phones/log-in", PhoneSessionController, :log_in
end
```

**Protected Routes (auth required):**
```elixir
scope "/", VideoConferenceWeb do
  pipe_through [:api, :require_api_authentication]
  delete "/phones/log-out", PhoneSessionController, :log_out
  # ... other protected routes
end
```

#### Authentication Helpers

- `fetch_current_scope_for_api` - Fetches scope for API routes
- `redirect_if_phone_is_authenticated` - Redirects if already authenticated (for registration pages)
- `put_user_token` - Generates unique user token per request

**Important:** Always pass `current_scope.phone` to context modules when performing queries.

### Project Structure

```
lib/
├── video_conference/          # Core contexts (business logic)
│   ├── accounts/             # Phone authentication & user management
│   ├── phone_books/          # Contact management
│   ├── shared_links/         # Shared conference link generation
│   └── telephone_switchboard/# Call routing logic
└── video_conference_web/     # Web interface layer
    ├── controllers/          # REST API endpoints (JSON)
    ├── channels/             # WebSocket channels for real-time communication
    ├── components/           # Phoenix components (LiveView, HEEx)
    └── router.ex             # Route definitions

assets/
├── js/                       # Frontend JavaScript (WebCodecs, WebTransport)
│   ├── group_socket.js       # HTTP/3 stream management
│   ├── video_decoder.js      # Video decoding with WebCodecs
│   ├── audio_decoder.js      # Audio decoding with WebCodecs
│   └── current_participant_camera.js # Camera capture & encoding
└── css/                      # Tailwind CSS styles

test/
├── support/
│   ├── conn_case.ex          # Connection test base
│   ├── data_case.ex          # Database test base
│   └── fixtures/             # Test data fixtures
```

### Key Conventions

1. **Contexts:** Organize business logic by domain (Accounts, PhoneBooks, SharedLinks)
2. **Scopes:** All public functions accept `Scope{phone: phone}` as first argument for filtering
3. **Forms:** Use `<.form>` and `<.input>` from Phoenix.Component
4. **Icons:** Use `<.icon name="hero-x-mark" />` (never Heroicons modules directly)
5. **Flash messages:** Rendered via `Layouts.app/1` with `<.flash_group>`
6. **Database:** SQLite3 via `ecto_sqlite3`, migration timestamps use `:utc_datetime`
7. **HTTP Client:** Use `:req` library (not HTTPoison/Tesla)
8. **Testing:** Use fixtures from `test/support/fixtures/` for consistent test data

<!-- phoenix:liveview-end -->
<!-- usage-rules-end -->