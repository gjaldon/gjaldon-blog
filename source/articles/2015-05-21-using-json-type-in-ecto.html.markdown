---
title: Using JSON Type in Ecto
date: 2015-05-21 19:01 UTC
tags: elixir, ecto
---

## Introduction

## Errors

## Creating a Postgrex Extension

## Configure Ecto with Custom Extension

## Custom Ecto Type

## Wrap-up



defmodule Streamline.JSON do
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
