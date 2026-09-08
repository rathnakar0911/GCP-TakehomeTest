package com.example.appa;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AppAHealthController {
    @Value("${APP_NAME:app-a}")
    private String appName;

    @GetMapping("/")
    public Map<String, String> root() {
        return Map.of("status", "UP", "application", appName);
    }
}
