package com.example.mcplugin;

import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;

/**
 * Простой HTTP сервер для health check.
 */
public class HealthHttpServer {
    private final HttpServer server;
    
    public HealthHttpServer(int port) {
        try {
            server = HttpServer.create(new InetSocketAddress(port), 0);
            server.createContext("/healthz", exchange -> {
                var response = "OK";
                exchange.sendResponseHeaders(200, response.length());
                try (OutputStream os = exchange.getResponseBody()) {
                    os.write(response.getBytes());
                }
            });
        } catch (IOException e) {
            throw new RuntimeException("Failed to create health server", e);
        }
    }
    
    public void start() {
        server.start();
    }
    
    public void stop() {
        server.stop(0);
    }
}
