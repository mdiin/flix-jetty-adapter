mod Jetty {
    import java.lang.Object;
    import java.io.{InputStream};
    import jakarta.servlet.{ServletInputStream, ServletOutputStream};
    import jakarta.servlet.http.{HttpServletRequest, HttpServletResponse};
    import org.eclipse.jetty.server.{
        AbstractConnectionFactory,
        Connector, 
        ConnectionFactory,
        Handler,
        HttpConfiguration,
        HttpConfiguration$Customizer,
        HttpConnectionFactory,
        ProxyConnectionFactory,
        Request,
        SecureRequestCustomizer,
        Server,
        ServerConnector
    };
    import org.eclipse.jetty.server.handler.{HandlerWrapper};
    import org.eclipse.jetty.servlet.{ServletContextHandler, ServletHandler};
    import org.eclipse.jetty.http2.server.{HTTP2CServerConnectionFactory, HTTP2ServerConnectionFactory, AbstractHTTP2ServerConnectionFactory};
    import org.eclipse.jetty.util.ssl.{SslContextFactory, SslContextFactory$Server};
    import org.eclipse.jetty.util.thread.{ThreadPool, QueuedThreadPool, ScheduledExecutorScheduler};

    type alias JettyConfig = {
        port = Int32,
        host = Option[String],
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
        sniHostCheck = Bool,
        maxIdleTime = Int64
    }

    pub def defaultConfig(): JettyConfig = {
        port = 8080,
        join = true,
        host = None,
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
        sniHostCheck = true,
        maxIdleTime = 200_000i64
    }

    enum JettyServer(Server)
    
    type alias RingResponseHeaders = Map[String, HeaderVal]

    type alias RingRequest = {
        serverPort = Int32,
        serverName = String,
        remoteAddr = String,
        uri = String,
        queryString = String,
        scheme = String,
        requestMethod = String,
        protocol = String,
        headers = RingResponseHeaders,
        contentType = String,
        contentLength = Option[Int32],
        characterEncoding = String,
        sslClientCert = Option[String],
        body = ServletInputStream
    }

    enum HeaderVal {
        case Single(String),
        case Multi(Nec[String])
    }

    pub enum RingResponseBody {
        case Bytes(Array[Int8, Static]),
        case String(String),
        case Absent
    }

   
    type alias RingResponse = {
        status = Int32,
        body = RingResponseBody,
        headers = RingResponseHeaders
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
        host: Option[String],
        maxIdleTime: Int64,
        proxy: Bool
    ): ServerConnector \ IO =
        import new org.eclipse.jetty.server.ServerConnector(Server, Array[ConnectionFactory, Static]): ServerConnector \ IO as newServerConnector;
        import new org.eclipse.jetty.server.HttpConnectionFactory(HttpConfiguration): HttpConnectionFactory \ IO as newHttpConnectionFactory;
        import new org.eclipse.jetty.server.ProxyConnectionFactory(): ProxyConnectionFactory \ IO as newProxyConnectionFactory;
        import org.eclipse.jetty.server.ServerConnector.setPort(Int32): Unit \ IO;
        import org.eclipse.jetty.server.ServerConnector.setHost(String): Unit \ IO;
        import org.eclipse.jetty.server.ServerConnector.setIdleTimeout(Int64): Unit \ IO;
        let httpConnectionFactory = newHttpConnectionFactory(httpConfiguration);
        let connectionFactories: Chain[ConnectionFactory] = Chain.empty()
            |> Chain.cons(checked_cast(httpConnectionFactory))
            |> c1 -> if (proxy) Chain.cons(checked_cast(newProxyConnectionFactory()), c1) else c1
            |> c2 -> if (h2c) Chain.cons(???, c2) else c2;
        let serverConnector = newServerConnector(server, Chain.toArray(Static, connectionFactories));
        setPort(serverConnector, port);
        match host {
            case Some(hostname) => setHost(serverConnector, hostname)
            case None => ()
        };
        setIdleTimeout(serverConnector, maxIdleTime);
        serverConnector

    def makeServer(options: JettyConfig): Server \ IO =
        import new org.eclipse.jetty.server.Server(ThreadPool): Server \ IO as newJettyServer;
        import new org.eclipse.jetty.util.thread.QueuedThreadPool(Int32, Int32, Int32): QueuedThreadPool \ IO as newQueuedThreadPool;
        import new org.eclipse.jetty.util.thread.ScheduledExecutorScheduler(): ScheduledExecutorScheduler \ IO as newScheduledExecutorScheduler;
        import org.eclipse.jetty.util.thread.QueuedThreadPool.setDaemon(Bool): Unit \ IO;
        import org.eclipse.jetty.server.Server.setStopAtShutdown(Bool): Unit \ IO;
        import org.eclipse.jetty.server.Server.addBean(Object): Bool \ IO;
        import org.eclipse.jetty.server.Server.setConnectors(Array[Connector, Static]): Unit \ IO;
        let queuedThreadPool = newQueuedThreadPool(10, 1, 1000);
        setDaemon(queuedThreadPool, false);
        let server = newJettyServer(checked_cast(queuedThreadPool));
        let schedulerBean = newScheduledExecutorScheduler();
        let httpConfiguration = httpConfig(options);
        addBean(server, checked_cast(schedulerBean));
        setStopAtShutdown(server, true);
        let httpConnector = httpConnector(
            server,
            httpConfiguration,
            false,
            a -> a,
            options.port,
            options.host,
            options.maxIdleTime,
            false
        );
        setConnectors(server, Array#{checked_cast(httpConnector)} @ Static);
        server

    def buildRequestRecord(request: HttpServletRequest): RingRequest \ IO =
        import jakarta.servlet.http.HttpServletRequest.getServerPort(): Int32 \ IO;
        import jakarta.servlet.http.HttpServletRequest.getServerName(): String \ IO;
        import jakarta.servlet.http.HttpServletRequest.getRemoteAddr(): String \ IO;
        import jakarta.servlet.http.HttpServletRequest.getRequestURI(): String \ IO;
        import jakarta.servlet.http.HttpServletRequest.getQueryString(): String \ IO;
        import jakarta.servlet.http.HttpServletRequest.getScheme(): String \ IO;
        import jakarta.servlet.http.HttpServletRequest.getMethod(): String \ IO;
        import jakarta.servlet.http.HttpServletRequest.getProtocol(): String \ IO;
        import jakarta.servlet.http.HttpServletRequest.getContentType(): String \ IO;
        import jakarta.servlet.http.HttpServletRequest.getContentLength(): Int32 \ IO;
        import jakarta.servlet.http.HttpServletRequest.getCharacterEncoding(): String \ IO;
        import jakarta.servlet.http.HttpServletRequest.getInputStream(): ServletInputStream \ IO;
        import java.lang.String.toLowerCase(): String \ IO;
        {
            serverPort = getServerPort(request),
            serverName = getServerName(request),
            remoteAddr = getRemoteAddr(request),
            uri = getRequestURI(request),
            queryString = getQueryString(request),
            scheme = getScheme(request),
            requestMethod = toLowerCase(getMethod(request)),
            protocol = getProtocol(request),
            headers = Map.empty(), // TODO
            contentType = getContentType(request),
            contentLength = if (getContentLength(request) >= 0) Some(getContentLength(request)) else None,
            characterEncoding = getCharacterEncoding(request),
            sslClientCert = None,
            body = getInputStream(request)
        }

    def contentType(headers: RingResponseHeaders): Option[String] =
        match Map.get("Content-Type", headers) {
            case Some(v) => match v {
                case HeaderVal.Single(header) => Some(header)
                case HeaderVal.Multi(hdrs) => Some(Nec.head(hdrs))
            }
            case None => None
        }

    def contentTypeCharset(_contentType: String): Option[String] =
        None // TODO

    def charset(response: RingResponse): Option[String] =
        Option.flatMap(contentTypeCharset, contentType(response.headers))

    def updateServletResponse(response: HttpServletResponse, responseRecord: RingResponse): Unit \ IO =
        // I am assuming that the HttpServletResponse is never null, though this *is* Java interop, so...
        import jakarta.servlet.http.HttpServletResponse.setStatus(Int32): Unit \ IO;
        import jakarta.servlet.http.HttpServletResponse.setHeader(String, String): Unit \ IO;
        import jakarta.servlet.http.HttpServletResponse.setContentType(String): Unit \ IO;
        import jakarta.servlet.http.HttpServletResponse.getOutputStream(): ServletOutputStream \ IO;
        import java.io.Closeable.close(): Unit \ IO;
        import java.io.OutputStream.write(Array[Int8, Static]): Unit \ IO as outputStreamWriteBytes;
        import java.io.Writer.write(String): Unit \ IO as writerWriteStr;
        import new java.io.BufferedWriter(##java.io.Writer): ##java.io.BufferedWriter \ IO as newBufferedWriter;
        import new java.io.OutputStreamWriter(##java.io.OutputStream): ##java.io.OutputStreamWriter \ IO as newOutputStreamWriter;
        import new java.io.OutputStreamWriter(##java.io.OutputStream, String): ##java.io.OutputStreamWriter \ IO as newOutputStreamWriterCharset;

        setStatus(response, responseRecord.status);
        Map.forEach((k, v) ->
            match v {
                case HeaderVal.Single(header) => setHeader(response, k, header)
                case HeaderVal.Multi(headers) => Nec.forEach(
                    h -> setHeader(response, k, h),
                    headers
                )
            },
            responseRecord.headers
        );

        // Content-Type header must be set by special method...
        match contentType(responseRecord.headers) {
            case Some(header) => setContentType(response, header)
            case None => ()
        };

        let responseOutputStream = getOutputStream(response);
        match responseRecord.body {
            case RingResponseBody.Bytes(bs) =>
                outputStreamWriteBytes(checked_cast(responseOutputStream), bs);
                close(checked_cast(responseOutputStream))
            case RingResponseBody.String(s) =>
                let cs = charset(responseRecord);
                let writer = match cs {
                    case Some(c) => newBufferedWriter(
                        checked_cast(newOutputStreamWriterCharset(
                            checked_cast(responseOutputStream),
                            c
                        ))
                    )
                    case None => newBufferedWriter(checked_cast(newOutputStreamWriter(checked_cast(responseOutputStream))))
                };
                writerWriteStr(checked_cast(writer), s);
                close(checked_cast(writer))
                
            case RingResponseBody.Absent => close(checked_cast(responseOutputStream))
        }

    def newServletHandler(handler: RingHandler, _options: JettyConfig): ServletHandler \ IO =
        new ServletHandler {
            def doHandle(
                _this: ServletHandler,
                _target: String,
                baseRequest: Request,
                request: HttpServletRequest,
                response: HttpServletResponse
            ): Unit =
                import org.eclipse.jetty.server.Request.setHandled(Bool): Unit \ IO;
                try {
                    let responseRecord = request
                        |> buildRequestRecord
                        |> handler;
                    updateServletResponse(response, responseRecord);
                    setHandled(baseRequest, true)
                } catch {
                    case ex: ##java.lang.Throwable =>
                        import java.lang.Throwable.getMessage(): String \ IO;
                        import jakarta.servlet.http.HttpServletResponse.sendError(Int32, String): Unit \ IO;
                        sendError(response, 500, getMessage(ex));
                        setHandled(baseRequest, true)
                }
        }

    def wrapHandler(handler: RingHandler, options: JettyConfig): ServletContextHandler \ IO =
        import new org.eclipse.jetty.servlet.ServletContextHandler(): ServletContextHandler \ IO as newServletContextHandler;
        import org.eclipse.jetty.servlet.ServletContextHandler.setAllowNullPathInfo(Bool): Unit \ IO;
        import org.eclipse.jetty.servlet.ServletContextHandler.setServletHandler(ServletHandler): Unit \ IO;
        let servletHandler = newServletHandler(handler, options);
        let servletContextHandler = newServletContextHandler();
        setAllowNullPathInfo(servletContextHandler, true);
        setServletHandler(servletContextHandler, servletHandler);
        servletContextHandler

    pub def runJetty(handler: RingHandler, config: JettyConfig): JettyServer \ IO =
        let server = makeServer(config);
        import org.eclipse.jetty.server.Server.start(): Unit \ IO;
        import org.eclipse.jetty.server.Server.join(): Unit \ IO;
        import org.eclipse.jetty.server.handler.HandlerWrapper.setHandler(Handler): Unit \ IO;
        let appHandler = wrapHandler(handler, config);
        setHandler(checked_cast(server), checked_cast(appHandler));
        start(server);
        if (config.join) join(server) else ();
        JettyServer.JettyServer(server)

    pub def stopJetty(jetty: JettyServer): JettyServer \ IO =
        import org.eclipse.jetty.server.Server.stop(): Unit \ IO;
        let server = match jetty {
            case JettyServer.JettyServer(s) => s
        };
        stop(server);
        jetty
}