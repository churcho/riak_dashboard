defmodule RiakDashboardWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component

  alias Phoenix.HTML.Form, as: HtmlForm
  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr(:id, :string, doc: "the optional id of flash container")
  attr(:flash, :map, default: %{}, doc: "the map of flash messages to display")
  attr(:title, :string, default: nil)
  attr(:kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup")
  attr(:rest, :global, doc: "the arbitrary HTML attributes to add to the flash container")

  slot(:inner_block, doc: "the optional inner block that renders the flash message")

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label="close">
          <.icon name="hero-x-mark-solid" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr(:rest, :global, include: ~w(href navigate patch))
  attr(:variant, :string, values: ~w(primary))
  slot(:inner_block, required: true)

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}
    assigns = assign(assigns, :class, Map.fetch!(variants, assigns[:variant]))

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={["btn", @class]} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={["btn", @class]} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:value, :any)

  attr(:type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)
  )

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"
  )

  attr(:errors, :list, default: [])
  attr(:checked, :boolean, doc: "the checked flag for checkbox inputs")
  attr(:prompt, :string, default: nil, doc: "the prompt for select inputs")
  attr(:options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2")
  attr(:multiple, :boolean, default: false, doc: "the multiple flag for select inputs")

  attr(:rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)
  )

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        HtmlForm.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="fieldset-label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class="checkbox checkbox-sm"
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="fieldset-label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={["w-full select", @errors != [] && "select-error"]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {HtmlForm.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="fieldset-label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={["w-full textarea", @errors != [] && "textarea-error"]}
          {@rest}
        >{HtmlForm.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="fieldset-label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={HtmlForm.normalize_value(@type, @value)}
          class={["w-full input", @errors != [] && "input-error"]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle-mini" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr(:class, :string, default: nil)

  slot(:inner_block, required: true)
  slot(:subtitle)
  slot(:actions)

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4", @class]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr(:id, :string, required: true)
  attr(:rows, :list, required: true)
  attr(:row_id, :any, default: nil, doc: "the function for generating the row id")
  attr(:row_click, :any, default: nil, doc: "the function for handling phx-click on each row")

  attr(:row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"
  )

  slot :col, required: true do
    attr(:label, :string)
  end

  slot(:action, doc: "the slot for showing user actions in the last table column")

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">Actions</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr(:title, :string, required: true)
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div>
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr(:name, :string, required: true)
  attr(:class, :string, default: "size-4")

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a badge/pill with consistent rectangular shape and semantic color.

  ## Variants

    * `:success` - Green for positive states (valid, OK, healthy)
    * `:warning` - Orange/amber for caution states (pending, joining)
    * `:error` - Red for error/destructive states (down, unreachable)
    * `:info` - Blue for informational states
    * `:neutral` - Default muted style

  ## Examples

      <.badge variant={:success}>OK</.badge>
      <.badge variant={:warning}>Pending</.badge>
      <.badge variant={:info} indicator>Live</.badge>
  """
  attr(:variant, :atom, default: :neutral, values: [:success, :warning, :error, :info, :neutral])
  attr(:indicator, :boolean, default: false)
  attr(:class, :string, default: "")
  slot(:inner_block, required: true)

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-xs font-semibold",
      badge_colors(@variant),
      @class
    ]}>
      <span :if={@indicator} class={["w-2 h-2 rounded-full", indicator_color(@variant)]} />
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp badge_colors(:success),
    do:
      "text-[#4A7C59] bg-[#E8F5E9] border border-[#C4E6C9] dark:text-[#34D399] dark:bg-[#0f3429] dark:border-[#166534]"

  defp badge_colors(:warning),
    do:
      "text-[#E69500] bg-[#FFF8E1] border border-[#FFE0B2] dark:text-[#f59e0b] dark:bg-[#422006] dark:border-[#92400e]"

  defp badge_colors(:error),
    do:
      "text-[#C75050] bg-[#FFEBEE] border border-[#FFCDD2] dark:text-[#f87171] dark:bg-[#3a1f22] dark:border-[#7f1d1d]"

  defp badge_colors(:info),
    do:
      "text-[#2D80D1] bg-[#E3F2FD] border border-[#BBDEFB] dark:text-[#60A5FA] dark:bg-[#12315a] dark:border-[#1e3a5f]"

  defp badge_colors(:neutral),
    do:
      "text-[#5A5A5A] bg-[#F0EFEB] border border-[#E0DDD6] dark:text-[#94A3B8] dark:bg-[#334155] dark:border-[#475569]"

  defp indicator_color(:success), do: "bg-green-500 animate-pulse"
  defp indicator_color(:warning), do: "bg-amber-500"
  defp indicator_color(:error), do: "bg-red-500"
  defp indicator_color(:info), do: "bg-blue-500"
  defp indicator_color(:neutral), do: "bg-gray-400"

  @doc """
  Generic modal dialog container for confirmations and alerts.

  ## Example

      <.dialog_modal
        id="delete-modal"
        show={@show_delete_modal}
        title="Delete item?"
        message="This action cannot be undone."
        variant={:error}
        on_cancel="close_delete_modal"
      >
        <:actions>
          <button phx-click="confirm_delete">Delete</button>
          <button phx-click="close_delete_modal">Cancel</button>
        </:actions>
      </.dialog_modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :variant, :atom, default: :error, values: [:error, :success, :info]
  attr :on_cancel, :string, default: nil
  attr :show_close, :boolean, default: true
  attr :class, :string, default: nil

  slot :actions, required: true

  def dialog_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      id={@id}
      class={["fixed inset-0 z-50", @class]}
      aria-labelledby={"#{@id}-title"}
      role="dialog"
      aria-modal="true"
    >
      <div
        class="fixed inset-0 bg-black/50 transition-opacity duration-200"
        phx-click={@on_cancel}
      />

      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div
            phx-mounted={
              JS.remove_class("opacity-0 translate-y-3 sm:translate-y-0 sm:scale-95", time: 200)
            }
            class="relative w-full max-w-lg transform overflow-hidden rounded-lg border border-[#EEEDEA] bg-white px-4 pt-5 pb-4 text-left shadow-xl opacity-0 translate-y-3 transition-all duration-200 sm:p-6 sm:my-8 dark:border-[#334155] dark:bg-[var(--or-bg-surface)] dark:text-[var(--or-fg-base)]"
          >
            <button
              :if={@show_close and @on_cancel}
              type="button"
              phx-click={@on_cancel}
              class="absolute top-3 right-3 rounded-md p-1 text-[#9CA3AF] hover:text-[#6B7280] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#e77117] dark:text-[#94A3B8] dark:hover:text-[#CBD5E1]"
            >
              <span class="sr-only">Close</span>
              <.icon name="hero-x-mark-mini" class="size-4" />
            </button>

            <div class="sm:flex sm:items-start">
              <div class={[
                "mx-auto flex size-12 shrink-0 items-center justify-center rounded-full sm:mx-0 sm:size-10",
                modal_icon_bg(@variant)
              ]}>
                <.icon name={modal_icon(@variant)} class={"size-6 #{modal_icon_fg(@variant)}"} />
              </div>
              <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                <h3
                  id={"#{@id}-title"}
                  class="text-base font-semibold text-[#111827] dark:text-[#E2E8F0]"
                >
                  {@title}
                </h3>
                <p class="mt-2 text-sm text-[#6B7280] dark:text-[#94A3B8]">
                  {@message}
                </p>
              </div>
            </div>
            <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse sm:gap-3">
              {render_slot(@actions)}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp modal_icon(:error), do: "hero-exclamation-triangle"
  defp modal_icon(:success), do: "hero-check"
  defp modal_icon(:info), do: "hero-information-circle"

  defp modal_icon_bg(:error), do: "bg-[#FEE2E2] dark:bg-[#3f1313]"
  defp modal_icon_bg(:success), do: "bg-[#DCFCE7] dark:bg-[#133526]"
  defp modal_icon_bg(:info), do: "bg-[#DBEAFE] dark:bg-[#102a52]"

  defp modal_icon_fg(:error), do: "text-[#DC2626] dark:text-[#FCA5A5]"
  defp modal_icon_fg(:success), do: "text-[#16A34A] dark:text-[#86EFAC]"
  defp modal_icon_fg(:info), do: "text-[#2563EB] dark:text-[#93C5FD]"

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(RiakDashboardWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(RiakDashboardWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
