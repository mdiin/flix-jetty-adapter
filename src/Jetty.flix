mod HttpStatus {
    pub enum Code {
        case OK,
        case NotFound,
        case BadRequest,
        case Unauthenticated,
        case Unauthorized
    }
}

mod Jetty {
    import java.lang.Object;
    import org.eclipse.jetty.server.{Connector, Server};
    import org.eclipse.jetty.util.thread.{ThreadPool, ScheduledExecutorScheduler};

    type alias JettyConfig = {
        port = Int32,
        join = Bool
    }

    enum JettyServer(Server)

    type alias RingRequest = {
        uri = String
    }

    type alias RingResponse = {
        status = HttpStatus.Code,
        body = String
    }

    type alias RingHandler = RingRequest -> RingResponse

    def makeServer(): Server \ IO =
        import new org.eclipse.jetty.server.Server(ThreadPool): ##org.eclipse.jetty.server.Server \ IO as newJettyServer;
        import new org.eclipse.jetty.util.thread.QueuedThreadPool(Int32, Int32, Int32): ##org.eclipse.jetty.util.thread.QueuedThreadPool \ IO as newQueuedThreadPool;
        import new org.eclipse.jetty.util.thread.ScheduledExecutorScheduler(): ##org.eclipse.jetty.util.thread.ScheduledExecutorScheduler \ IO as newScheduledExecutorScheduler;
        import org.eclipse.jetty.util.thread.QueuedThreadPool.setDaemon(Bool): Unit \ IO;
        import org.eclipse.jetty.server.Server.setStopAtShutdown(Bool): Unit \ IO;
        import org.eclipse.jetty.server.Server.addBean(Object): Bool \ IO;
        // import org.eclipse.jetty.server.Server.setConnectors(Connector): Unit \ IO; // TODO: How to tell it to use Connector[] ??
        let queuedThreadPool = newQueuedThreadPool(10, 1, 1000);
        let _ = setDaemon(queuedThreadPool, false);
        let pool: ##org.eclipse.jetty.util.thread.ThreadPool = checked_cast(queuedThreadPool);
        let server = newJettyServer(pool);
        let schedulerBean = newScheduledExecutorScheduler();
        let schedulerBeanObj: ##java.lang.Object = checked_cast(schedulerBean);
        addBean(server, schedulerBeanObj);
        setStopAtShutdown(server, true);
        server

    pub def runJetty(_handler: RingHandler, config: JettyConfig): JettyServer \ IO =
        let server = makeServer();
        import org.eclipse.jetty.server.Server.start(): Unit \ IO;
        import org.eclipse.jetty.server.Server.join(): Unit \ IO;
        start(server);
        if (config.join) join(server) else ();
        JettyServer.JettyServer(server)

    pub def stopJetty(jetty: JettyServer): JettyServer = ???
}