mod Jetty {
    import org.eclipse.jetty.Server;

    type alias JettyConfig = {
        port = Int32,
        join = Bool
    }

    enum HttpStatus {
        case OK,
        case NotFound,
        case BadRequest,
        case Unauthenticated,
        case Unauthorized
    }

    enum JettyServer(Server)

    type alias RingRequest = {
        uri = String
    }

    type alias RingResponse = {
        status = HttpStatus,
        body = String
    }

    //type alias RingHandler = RingRequest -> RingResponse

    //def makeServer(): JettyServer =
        //import new org.eclipse.jetty.Server(org.eclipse.jetty.util.threads.ThreadPool): ##org.eclipse.jetty.Server \ IO as newJettyServer;


    pub def runJetty(handler: RingHandler, config: JettyConfig): JettyServer = ???

    pub def stopJetty(jetty: JettyServer): JettyServer = ???
}