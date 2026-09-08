package com.example.appa;

import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api/app-a")
public class AppAController {
    private static final Logger log = LoggerFactory.getLogger(AppAController.class);

    @Value("${APP_NAME:app-a}")
    private String appName;

    @Value("${CLUSTER_NAME:unknown}")
    private String clusterName;

    @GetMapping("/hello")
    public Map<String, Object> hello(HttpServletRequest request) {
        return response(request, 200, "Hello from Application A");
    }

    @GetMapping("/")
    public Map<String, Object> root() {
        return Map.of("status", "UP", "application", appName);
    }

    @GetMapping("/health")
    public Map<String, Object> health(HttpServletRequest request) {
        return response(request, 200, "healthy");
    }

    @GetMapping("/info")
    public Map<String, Object> info(HttpServletRequest request) {
        return Map.of("application", appName, "cluster", clusterName,
                "pod", System.getenv().getOrDefault("HOSTNAME", "unknown"),
                "timestamp", Instant.now().toString());
    }

    @GetMapping("/delay")
    public Map<String, Object> delay(@RequestParam(defaultValue = "200") long ms,
                                     HttpServletRequest request) throws InterruptedException {
        long bounded = Math.max(0, Math.min(ms, 5000));
        Thread.sleep(bounded);
        return response(request, 200, "Delayed response");
    }

    @GetMapping("/error")
    public ResponseEntity<Map<String, Object>> error(HttpServletRequest request) {
        long start = System.nanoTime();
        long latency = elapsedMs(start);
        log.error("{\"severity\":\"ERROR\",\"application\":\"{}\",\"cluster\":\"{}\",\"endpoint\":\"/api/app-a/error\",\"http_status\":500,\"latency_ms\":{},\"message\":\"Intentional assessment error\"}",
                appName, clusterName, latency);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("application", appName, "error", "intentional assessment error"));
    }

    private Map<String, Object> response(HttpServletRequest request, int status, String message) {
        long start = System.nanoTime();
        Map<String, Object> body = Map.of(
                "application", appName,
                "cluster", clusterName,
                "pod", System.getenv().getOrDefault("HOSTNAME", "unknown"),
                "message", message,
                "timestamp", Instant.now().toString());
        long latency = elapsedMs(start);
        log.info("{\"severity\":\"INFO\",\"application\":\"{}\",\"cluster\":\"{}\",\"endpoint\":\"{}\",\"http_status\":{},\"latency_ms\":{}}",
                appName, clusterName, request.getRequestURI(), status, latency);
        return body;
    }

    private long elapsedMs(long start) {
        return (System.nanoTime() - start) / 1_000_000;
    }
}
