---
title: Using JSON Type in Ecto
date: 2015-05-21 19:01 UTC
tags: elixir, ecto
---

last updated: July 14, 2015

## Update

As of Ecto v0.13.0, `:map` type is already supported and is a `jsonb` column when using Postgres.
For other databases, a `text` column is used that emulates `json`. This means you can now just
do the following to use `jsonb`:

~~~elixir

# migration

defmodule MyApp.UserMigration do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :meta, :map
    end
  end
end

# model

defmodule MyApp.User do
  use Ecto.Model

  schema "users" do
    field :meta, :map
  end
end
~~~

Simple! Keep in mind though that there isn't yet first-class support for queries on map fields.
For that, you will still have to rely on `fragment/2`. If you want to use a `json` column (not `jsonb`), you will still need to create a [custom ecto type](/articles/using-json-type-in-ecto.html#custom-ecto-type) but can skip [creating a Postgrex extension](/articles/using-json-type-in-ecto.html#creating-a-postgrex-extension) and [configuring Ecto with a custom extension](/articles/using-json-type-in-ecto.html#configure-ecto-with-custom-extension).

## Introduction

In a recent project, I had the chance to use JSON in `Ecto`. Although `Ecto` does not
currently support JSON, it does provide us with the capability to define custom
types. In this blog post, we'll go through how we can use the JSON type in `Ecto`.
Did I mention JSON enough already?


## Custom Ecto Type

`Ecto` provides a behaviour module called `Ecto.Type`. It requires us to define four
functions in the module that uses it. These functions are `type`, `cast/1`, `load/1` and
`dump/1`. Note that these functions each expect a certain format in their return values
which you could review in the [`Ecto.Type` docs](http://hexdocs.pm/ecto/Ecto.Type.html).

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
~~~

In here, we do not do any encoding or decoding of the JSON data. See that we pass just
`{:ok, value}` to both `load/1` and `dump/1` which are callback functions that get called
when loading data and dumping data to the database, respectively.

This is because we will be doing the JSON serialization in `Postgrex`, which is the Postgres
adapter used by Ecto. It turns out, defining a custom Ecto type for JSON is not enough. If
we pass it as a type to a field in an Ecto model like `field :info, MyApp.JSON`, we will
get the error:

~~~console

** (exit) an exception was raised:
** (ArgumentError) no extension found for oid `114`
    (postgrex) lib/postgrex/types.ex:285: Postgrex.Types.fetch!/2
    ...
~~~

The id `114` refers to the JSON data type in `Postgres` and this error just says that
Postgrex does not recognize that data type. But like `Ecto`, `Postgrex` can be extended
so it knows how to serialize Postgres types to and from Elixir values.


## Creating a Postgrex Extension

We will need to use the behaviour module `Postgrex.Extension` and define the five functions
it requires, which are `decode/4`, `encode/4`, `format/1`, `init/2`, and `matching/1`. To
learn more about what each of these callbacks expect, review the [`Postgrex.Extension` docs](http://hexdocs.pm/postgrex/Postgrex.Extension.html).

Our Postgrex extension will be defined as:

~~~elixir

  defmodule MyApp.JSONExtension do
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
~~~

What this module does is it accepts a JSON parser library and uses this library to encode
and decode JSON data. This extension makes `Postgrex` recognize both `json` and `jsonb`
data types.


## Configure Ecto with Custom Extension

Now how do we use `MyApp.Extension` in `Ecto`?

`Ecto` supports an `:extensions` option in its configuration which can be used like below:

~~~elixir

  config :my_app, MyApp.Repo,
    adapter: Ecto.Adapters.Postgres,
    extensions: [{MyApp.JSONExtension, [library: Poison]}],
    ...
~~~

Make sure to pass a library option or else our custom JSON Extension will raise an error.
Also, we use `Poison` above but feel free to use whatever JSON parser library you are most
comfortable with.

Using `field :info, MyApp.JSON` in one of our Ecto models and then restarting our app should
now work without error!


## How to Query on JSON Columns

Since `Ecto` does not yet have first-class support for JSON, we will need to rely on
the `fragment` helper when writing our `Ecto` queries. This enables us to send queries
directly to the database. For example:

~~~elixir

  from(User in query,
    where: fragment("?->>'first_name' == ?", u.info, "John"))
~~~

The above query will filter our users and return only records with the value `"John"` as
`first_name` in their `info` column. We fallback to plain old PostgreSQL queries in our
`fragment`.


## Wrap-up

At the moment, to support JSON we will need to define two modules to extend both `Postgrex`
and `Ecto`. Eventually, `Postgrex` will ship with out-of-the-box support for JSON so that will
minimize the set-up for using `Ecto`. Until then, it is easy to copy-paste code.

Oh, and if you prefer to work with `jsonb` instead of `json`, just change the return value
of `type/1` in `MyApp.JSON` to `:jsonb` and you're good to go. The `MyApp.JSONExtension` already
extends `Postgrex` to support the `:jsonb` data type.


##### References:

  - Where the above <a href="https://github.com/ericmj/postgrex#extensions" target="_blank">Postgrex Extension</a> was ripped from
  - <a href="https://twitter.com/emjii" target="_blank">Eric</a> helped me get unstuck!
  - <a href="http://clarkdave.net/2013/06/what-can-you-do-with-postgresql-and-json/" target="_blank">What can you do with Postgresql and JSON</a>
