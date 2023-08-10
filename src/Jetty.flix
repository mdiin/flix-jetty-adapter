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
    import org.eclipse.jetty.server.{Connector, ConnectionFactory, HttpConfiguration, HttpConfiguration$Customizer, SecureRequestCustomizer, Server, ServerConnector};
    import org.eclipse.jetty.http2.server.{HTTP2CServerConnectionFactory, HTTP2ServerConnectionFactory, AbstractHTTP2ServerConnectionFactory};
    import org.eclipse.jetty.util.ssl.{SslContextFactory, SslContextFactory$Server};
    import org.eclipse.jetty.util.thread.{ThreadPool, QueuedThreadPool, ScheduledExecutorScheduler};

    type alias JettyConfig = {
        port = Int32,
        join = Bool,
        sslPort = Int32,
        ssl = Bool,
        secureScheme = String,
        outputBufferSize = Int32,
        requestHeaderSize = Int32,
        responseHeaderSize = Int32,
        sendServerVersion = Bool,
        sendDateHeader = Bool,
        headerCacheSize = Int32,
        sniRequired = Bool,
        sniHostCheck = Bool
    }

    pub def defaultConfig(): JettyConfig = {
        port = 8080,
        join = true,
        sslPort = 443,
        ssl = false,
        secureScheme = "https",
        outputBufferSize = 32768,
        requestHeaderSize = 8192,
        responseHeaderSize = 8192,
        sendServerVersion = true,
        sendDateHeader = false,
        headerCacheSize = 512,
        sniRequired = false,
        sniHostCheck = true
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

    def httpConfig(options: JettyConfig): HttpConfiguration \ IO =
        import new org.eclipse.jetty.server.SecureRequestCustomizer(): SecureRequestCustomizer \ IO as newSecureRequestCustomizer;
        import org.eclipse.jetty.server.SecureRequestCustomizer.setSniRequired(Bool): Unit \ IO;
        import org.eclipse.jetty.server.SecureRequestCustomizer.setSniHostCheck(Bool): Unit \ IO;
        let secureRequestCustomizer = newSecureRequestCustomizer();
        setSniRequired(secureRequestCustomizer, options.sniRequired);
        setSniHostCheck(secureRequestCustomizer, options.sniHostCheck);
        
        import new org.eclipse.jetty.server.HttpConfiguration(): HttpConfiguration \ IO as newHttpConfiguration;
        import org.eclipse.jetty.server.HttpConfiguration.setSecureScheme(String): Unit \ IO;
        import org.eclipse.jetty.server.HttpConfiguration.setOutputBufferSize(Int32): Unit \ IO;
        import org.eclipse.jetty.server.HttpConfiguration.setRequestHeaderSize(Int32): Unit \ IO;
        import org.eclipse.jetty.server.HttpConfiguration.setResponseHeaderSize(Int32): Unit \ IO;
        import org.eclipse.jetty.server.HttpConfiguration.setSendServerVersion(Bool): Unit \ IO;
        import org.eclipse.jetty.server.HttpConfiguration.setSendDateHeader(Bool): Unit \ IO;
        import org.eclipse.jetty.server.HttpConfiguration.setHeaderCacheSize(Int32): Unit \ IO;
        import org.eclipse.jetty.server.HttpConfiguration.addCustomizer(##org.eclipse.jetty.server.HttpConfiguration$Customizer): Unit \ IO;
        let httpConfiguration = newHttpConfiguration();
        setSecureScheme(httpConfiguration, options.secureScheme);
        setOutputBufferSize(httpConfiguration, options.outputBufferSize);
        setRequestHeaderSize(httpConfiguration, options.requestHeaderSize);
        setResponseHeaderSize(httpConfiguration, options.responseHeaderSize);
        setSendServerVersion(httpConfiguration, options.sendServerVersion);
        setSendDateHeader(httpConfiguration, options.sendDateHeader);
        setHeaderCacheSize(httpConfiguration, options.headerCacheSize);
        addCustomizer(httpConfiguration, checked_cast(secureRequestCustomizer));
        httpConfiguration

    def httpConnector(
        server: Server,
        httpConfiguration: HttpConfiguration,
        h2c: Bool,
        h2cConfigurer: AbstractHTTP2ServerConnectionFactory -> AbstractHTTP2ServerConnectionFactory,
        port: Int32,
        host: String,
        maxIdleTime: Int32,
        proxy: Bool
    ): ServerConnector =
        import new org.eclipse.jetty.server.ServerConnector(Server, Array[ConnectionFactory, Static]): ServerConnector \ IO as newServerConnector;
        // let connectionFactories = 
        ???

    def makeServer(options: JettyConfig): Server \ IO =
        import new org.eclipse.jetty.server.Server(ThreadPool): Server \ IO as newJettyServer;
        import new org.eclipse.jetty.util.thread.QueuedThreadPool(Int32, Int32, Int32): QueuedThreadPool \ IO as newQueuedThreadPool;
        import new org.eclipse.jetty.util.thread.ScheduledExecutorScheduler(): ScheduledExecutorScheduler \ IO as newScheduledExecutorScheduler;
        import org.eclipse.jetty.util.thread.QueuedThreadPool.setDaemon(Bool): Unit \ IO;
        import org.eclipse.jetty.server.Server.setStopAtShutdown(Bool): Unit \ IO;
        import org.eclipse.jetty.server.Server.addBean(Object): Bool \ IO;
        import org.eclipse.jetty.server.Server.setConnectors(Array[Connector, Static]): Unit \ IO;
        let queuedThreadPool = newQueuedThreadPool(10, 1, 1000);
        let _ = setDaemon(queuedThreadPool, false);
        let pool: ThreadPool = checked_cast(queuedThreadPool);
        let server = newJettyServer(pool);
        let schedulerBean = newScheduledExecutorScheduler();
        let schedulerBeanObj: Object = checked_cast(schedulerBean);
        let httpConfiguration = httpConfig(options);
        addBean(server, schedulerBeanObj);
        setStopAtShutdown(server, true);
        setConnectors(server, Array#{} @ Static);
        server

    pub def runJetty(_handler: RingHandler, config: JettyConfig): JettyServer \ IO =
        let server = makeServer(config);
        import org.eclipse.jetty.server.Server.start(): Unit \ IO;
        import org.eclipse.jetty.server.Server.join(): Unit \ IO;
        start(server);
        if (config.join) join(server) else ();
        JettyServer.JettyServer(server)

    pub def stopJetty(jetty: JettyServer): JettyServer = ???
}