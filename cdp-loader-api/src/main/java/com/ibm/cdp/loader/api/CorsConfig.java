package com.ibm.cdp.loader.api;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * CORS configuration — permits only the local React frontend origin.
 * This prevents cross-site access from other origins in production.
 */
@Configuration
public class CorsConfig {

    /**
     * Allowed frontend origin. Configure via VITE_API_BASE_URL.
     * Defaults to localhost:5173 (Vite dev server).
     */
    private static final String[] ALLOWED_ORIGINS = {
        "http://localhost:3000",
        "http://localhost:5173"
    };

    @Bean
    public WebMvcConfigurer corsConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/api/**")
                        .allowedOrigins(ALLOWED_ORIGINS)
                        .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                        .allowedHeaders("*")
                        .maxAge(3600);
            }
        };
    }
}
