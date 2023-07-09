defmodule Flop.Phoenix.Pagination do
  @moduledoc false

  alias Flop.Phoenix.Misc
  alias Phoenix.LiveView.JS

  require Logger

  def path_on_paginate_error_msg do
    """
    path or on_paginate attribute is required

    At least one of the mentioned attributes is required for the pagination
    component. Combining them will append a JS.patch command to the on_paginate
    command.

    The :path value can be a path as a string, a
    {module, function_name, args} tuple, a {function, args} tuple, or an 1-ary
    function.

    ## Examples

        <Flop.Phoenix.pagination
          meta={@meta}
          path={~p"/pets"}
        />

    or

        <Flop.Phoenix.pagination
          meta={@meta}
          path={{Routes, :pet_path, [@socket, :index]}}
        />

    or

        <Flop.Phoenix.pagination
          meta={@meta}
          path={{&Routes.pet_path/3, [@socket, :index]}}
        />

    or

        <Flop.Phoenix.pagination
          meta={@meta}
          path={&build_path/1}
        />

    or

        <Flop.Phoenix.pagination
          meta={@meta}
          on_paginate={JS.push("paginate")}
        />

    or

        <Flop.Phoenix.pagination
          meta={@meta}
          path={&build_path/1}
          on_paginate={JS.dispatch("scroll-to", to: "#my-table")}
        />
    """
  end

  @spec default_opts() :: [Flop.Phoenix.pagination_option()]
  def default_opts do
    [
      current_link_attrs: [
        class: "pagination-link is-current",
        aria: [current: "page"]
      ],
      disabled_class: "disabled",
      ellipsis_attrs: [class: "pagination-ellipsis"],
      ellipsis_content: Phoenix.HTML.raw("&hellip;"),
      next_link_attrs: [
        aria: [label: "Go to next page"],
        class: "pagination-next"
      ],
      next_link_content: "Next",
      page_links: :all,
      pagination_link_aria_label: &"Go to page #{&1}",
      pagination_link_attrs: [class: "pagination-link"],
      pagination_list_attrs: [class: "pagination-list"],
      previous_link_attrs: [
        aria: [label: "Go to previous page"],
        class: "pagination-previous"
      ],
      previous_link_content: "Previous",
      wrapper_attrs: [
        class: "pagination",
        role: "navigation",
        aria: [label: "pagination"]
      ]
    ]
  end

  def merge_opts(opts) do
    default_opts()
    |> Misc.deep_merge(Misc.get_global_opts(:pagination))
    |> Misc.deep_merge(opts)
  end

  def click_cmd(on_paginate, nil), do: on_paginate
  def click_cmd(on_paginate, path), do: JS.patch(on_paginate, path)

  def max_pages(:all, total_pages), do: total_pages
  def max_pages(:hide, _), do: 0
  def max_pages({:ellipsis, max_pages}, _), do: max_pages

  def get_page_link_range(current_page, max_pages, total_pages) do
    # number of additional pages to show before or after current page
    additional = ceil(max_pages / 2)

    cond do
      max_pages >= total_pages ->
        1..total_pages

      current_page + additional >= total_pages ->
        (total_pages - max_pages + 1)..total_pages

      true ->
        first = max(current_page - additional + 1, 1)
        last = min(first + max_pages - 1, total_pages)
        first..last
    end
  end

  def build_page_link_helper(_meta, nil), do: fn _ -> nil end

  def build_page_link_helper(meta, path) do
    query_params = build_query_params(meta)

    fn page ->
      params = maybe_put_page(query_params, page)
      Flop.Phoenix.build_path(path, params)
    end
  end

  defp build_query_params(meta) do
    meta.flop
    |> ensure_page_based_params()
    |> Flop.Phoenix.to_query(backend: meta.backend, for: meta.schema)
  end

  @doc """
  Takes a `Flop` struct and ensures that the only pagination parameters set are
  `:page` and `:page_size`. `:offset` and `:limit` are set to nil.

  ## Examples

      iex> flop = %Flop{limit: 2}
      iex> ensure_page_based_params(flop)
      %Flop{
        limit: nil,
        offset: nil,
        page: nil,
        page_size: 2
      }
  """
  @spec ensure_page_based_params(Flop.t()) :: Flop.t()
  def ensure_page_based_params(%Flop{} = flop) do
    %{
      flop
      | after: nil,
        before: nil,
        first: nil,
        last: nil,
        limit: nil,
        offset: nil,
        page_size: flop.page_size || flop.limit,
        page: flop.page
    }
  end

  defp maybe_put_page(params, 1), do: Keyword.delete(params, :page)
  defp maybe_put_page(params, page), do: Keyword.put(params, :page, page)

  def attrs_for_page_link(page, %{current_page: page}, opts) do
    add_page_link_aria_label(opts[:current_link_attrs], page, opts)
  end

  def attrs_for_page_link(page, _meta, opts) do
    add_page_link_aria_label(opts[:pagination_link_attrs], page, opts)
  end

  defp add_page_link_aria_label(attrs, page, opts) do
    aria_label = opts[:pagination_link_aria_label].(page)

    Keyword.update(
      attrs,
      :aria,
      [label: aria_label],
      &Keyword.put(&1, :label, aria_label)
    )
  end
end
