---
title: The Phoenix Pipeline
date: 2015-07-18 16:32 UTC
tags: elixir, phoenix
---

### Introduction

Phoenix's design is simple and elegant. At its core, it is just a bunch of `plug`s that run
sequentially when a request comes in up to the point that Phoenix sends a response. Each of these
plugs either apply a transformation to the connection or trigger a side-effect such as logging.
This simplicity in design is due to the adoption of the [Plug](https://github.com/elixir-lang/plug) specification and the decision to further decompose the series of plugs into logical groups.

### Pipeline Composition

There are three main pipelines within the larger Phoenix pipeline. These are the `Endpoint`, `Router`
and `Controller` pipelines. As an overview, all requests processed by Phoenix will go through the
`Endpoint` pipeline which, at the end, calls the router plug and triggers the `Router` pipeline.
The `Router` will then match a route to its corresponding controller action and dispatch to it. This
dispatch is just another call to a `Controller` plug which executes its own pipeline before finally invoking the matched action.

Let's look into these pipelines in more detail.

### Endpoint Pipeline


### Router Pipeline

### Controller Pipeline

