# Flix Jetty Adapter

An adapter for embedding a Jetty servlet container in your Flix program.

## Status: Pre-alpha

Use at your own risk, but mostly please don't use at all. Yet!

# Goals

Features this adapter aims to cover:

* HTTP
* HTTPS
* HTTP2
* Websockets

Properties this codebase aims to have:

* Ease of use
* Good documentation
* Type safety
* Ease of maintenance

# Non-goals

This adapter does not and will not provide any of these:

* An HTTP router
* An HTTP abstraction layer
* HTML templating
* Opinions on what you can and cannot do with your Jetty instance

# Inspiration

* [sunng87's ring-jetty9-adapter](https://github.com/sunng87/ring-jetty9-adapter/tree/master)
    * This code is actually a port from Clojure to Flix based on the amazing work done by sunng87 :pray: