package com.example.mcplugin.redis;

import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPubSub;

/**
 * Redis подписчик для получения событий от economy-api.
 */
public class RedisSubscriber {
    private final String host;
    private final int port;
    private Jedis jedis;
    private Thread subscriberThread;
    
    public RedisSubscriber(String host, int port) {
        this.host = host;
        this.port = port;
    }
    
    public void start() {
        subscriberThread = new Thread(() -> {
            try (var jedisClient = new Jedis(host, port)) {
                this.jedis = jedisClient;
                
                var pubSub = new JedisPubSub() {
                    @Override
                    public void onMessage(String channel, String message) {
                        handleMessage(channel, message);
                    }
                };
                
                jedis.subscribe(pubSub, "purchase:confirmed");
                    } catch (Exception e) {
            // Redis subscription failed
        }
        });
        
        subscriberThread.start();
    }
    
    private void handleMessage(String channel, String message) {
        if ("purchase:confirmed".equals(channel)) {
            var parts = message.split(":");
            if (parts.length >= 3) {
                var userId = parts[0];
                var itemId = parts[1];
                var transactionId = parts[2];
                
                // Purchase confirmed
            }
        }
    }
    
    public void close() {
        if (jedis != null) {
            jedis.close();
        }
        
        if (subscriberThread != null && subscriberThread.isAlive()) {
            subscriberThread.interrupt();
        }
    }
}
