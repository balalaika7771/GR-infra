package com.example.economy.events;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/** Публикатор событий в Redis pub/sub. */
@Component
public class RedisPublisher {
    private final StringRedisTemplate template;

    public RedisPublisher(StringRedisTemplate template) {
        this.template = template;
    }

    public void publish(String channel, String payload) {
        template.convertAndSend(channel, payload);
    }
}
