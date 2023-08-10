use Jetty;

def main(): Unit \ IO =
    let _s = Jetty.runJetty(_req -> { status = HttpStatus.Code.OK(), body = "Foo" }, { port = 8000, join = true | Jetty.defaultConfig() });
    println("Yes!")