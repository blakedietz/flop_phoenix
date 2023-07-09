defmodule Flop.Phoenix.Misc do
  @moduledoc false

  alias Phoenix.LiveView.JS

  require Logger

  @doc """
  Deep merge for keyword lists.

      iex> deep_merge(
      ...>   [aria: [role: "navigation"]],
      ...>   [aria: [label: "pagination"]]
      ...> )
      [aria: [role: "navigation", label: "pagination"]]

      iex> deep_merge(
      ...>   [class: "a"],
      ...>   [class: "b"]
      ...> )
      [class: "b"]
  """
  @spec deep_merge(keyword, keyword) :: keyword
  def deep_merge(a, b) when is_list(a) and is_list(b) do
    Keyword.merge(a, b, &do_deep_merge/3)
  end

  defp do_deep_merge(_key, a, b) when is_list(a) and is_list(b) do
    deep_merge(a, b)
  end

  defp do_deep_merge(_key, _, b), do: b

  @doc """
  Puts a `value` under `key` only if the value is not `nil`, `[]` or `%{}`.

  If a `:default` value is passed, it only puts the value into the list if the
  value does not match the default value.

      iex> maybe_put([], :a, "b")
      [a: "b"]

      iex> maybe_put([], :a, nil)
      []

      iex> maybe_put([], :a, [])
      []

      iex> maybe_put([], :a, %{})
      []

      iex> maybe_put([], :a, "a", "a")
      []

      iex> maybe_put([], :a, "a", "b")
      [a: "a"]
  """
  @spec maybe_put(keyword, atom, any, any) :: keyword
  def maybe_put(params, key, value, default \\ nil)
  def maybe_put(keywords, _, nil, _), do: keywords
  def maybe_put(keywords, _, [], _), do: keywords
  def maybe_put(keywords, _, map, _) when map == %{}, do: keywords
  def maybe_put(keywords, _, val, val), do: keywords
  def maybe_put(keywords, key, value, _), do: Keyword.put(keywords, key, value)

  @doc """
  Puts the order params of a into a keyword list only if they don't match the
  defaults passed as the last argument.
  """
  @spec maybe_put_order_params(keyword, Flop.t() | map, map) :: keyword
  def maybe_put_order_params(
        params,
        %{order_by: order_by, order_directions: order_directions},
        %{order_by: order_by, order_directions: order_directions}
      ),
      do: params

  def maybe_put_order_params(
        params,
        %{order_by: order_by, order_directions: order_directions},
        _
      ) do
    params
    |> maybe_put(:order_by, order_by)
    |> maybe_put(:order_directions, order_directions)
  end

  @doc """
  Returns the global opts derived from a function referenced in the application
  environment.
  """
  @spec get_global_opts(atom) :: keyword
  def get_global_opts(component)
      when component in [:cursor_pagination, :pagination, :table] do
    case opts_func(component) do
      nil -> []
      {module, func} -> apply(module, func, [])
    end
  end

  defp opts_func(component) do
    :flop_phoenix
    |> Application.get_env(component, [])
    |> Keyword.get(:opts)
  end

  def click_cmd(on_paginate, nil), do: on_paginate
  def click_cmd(on_paginate, path), do: JS.patch(on_paginate, path)

  @doc """
  Validates that either a path helper in the right format or an event are
  assigned, but not both.
  """
  def validate_path_or_event!(%{path: {module, function, args}, event: nil}, _)
      when is_atom(module) and is_atom(function) and is_list(args),
      do: :ok

  def validate_path_or_event!(%{path: {function, args}, event: nil}, _)
      when is_function(function) and is_list(args),
      do: :ok

  def validate_path_or_event!(%{path: path, event: nil}, _)
      when is_binary(path) or is_function(path, 1),
      do: :ok

  def validate_path_or_event!(%{path: nil, event: event}, _)
      when is_binary(event),
      do: :ok

  def validate_path_or_event!(_, error_msg), do: raise(ArgumentError, error_msg)

  @doc """
  Validates that either a path attribute or an on_paginate attribute is set.
  """
  def validate_path_or_on_paginate!(%{path: {module, function, args}}, _)
      when is_atom(module) and is_atom(function) and is_list(args),
      do: :ok

  def validate_path_or_on_paginate!(%{path: {function, args}}, _)
      when is_function(function) and is_list(args),
      do: :ok

  def validate_path_or_on_paginate!(%{path: path}, _)
      when is_binary(path) or is_function(path, 1),
      do: :ok

  def validate_path_or_on_paginate!(%{on_paginate: %JS{}}, _),
    do: :ok

  def validate_path_or_on_paginate!(%{event: event}, _)
      when is_binary(event),
      do: :ok

  def validate_path_or_on_paginate!(_, error_msg),
    do: raise(ArgumentError, error_msg)
end
