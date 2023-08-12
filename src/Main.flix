use Jetty;

def main(): Unit \ IO =
    let _s = Jetty.runJetty(_req -> {
        status = 200,
        body = Jetty.RingResponseBody.String("Foo"),
        headers = Map.empty()
    }, { port = 8000, join = true | Jetty.defaultConfig() });
    println("Yes!")