---
title: Using JSON Type in Ecto
date: 2015-05-21 19:01 UTC
tags: elixir, ecto
---

## Introduction

In a recent project, I had the chance to use JSON in `Ecto`. Although `Ecto` does not
currently support JSON, it does provide us with the capability to define custom
types. In this blog post, we'll go through how we can use the JSON type and see
how we can do queries on JSON columns in `Ecto`. Did I mention JSON enough already?


## Custom Ecto Type

`Ecto` provides a behaviour module called `Ecto.Type`. It requires us to define four
functions in the module that uses it. These functions are `type`, `cast/1`, `load/1` and
`dump/1`. Note that these functions each expect a certain format in their return values
that you could review in the [`Ecto.Type` docs](http://hexdocs.pm/ecto/Ecto.Type.html).

Let's go ahead and define our JSON Ecto type:

~~~elixir

defmodule MyApp.JSON do
  @behaviour Ecto.Type

  def type, do: :json
  def cast(value), do: {:ok, value}
  def blank?(_), do: false

  def load(value) do
    {:ok, value}
  end

  def dump(value) do
    {:ok, value}
  end
end


defmodule Streamline.JSONExtension do
  alias Postgrex.TypeInfo

  @behaviour Postgrex.Extension
  @json ["json", "jsonb"]

  def init(_parameters, opts),
    do: Keyword.fetch!(opts, :library)

  def matching(_library),
    do: [type: "json", type: "jsonb"]

  def format(_library),
    do: :binary

  def encode(%TypeInfo{type: "json"}, map, _state, library),
    do: library.encode!(map)
  def encode(%TypeInfo{type: "jsonb"}, map, _state, library),
    do: <<1, library.encode!(map)::binary>>

  def decode(%TypeInfo{type: "json"}, json, _state, library),
    do: library.decode!(json)
  def decode(%TypeInfo{type: "jsonb"}, <<1, json::binary>>, _state, library),
    do: library.decode!(json)
end


config :streamlinevc, Streamline.Repo,
  adapter: Ecto.Adapters.Postgres,
  extensions: [{Streamline.JSONExtension, [library: Poison]}],
  username: "postgres",
  password: "postgres",
  database: "manang_dev",
  size: 10
