package com.example.demo;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.Map;

/**
 * Holds a request so native-sidecar drain can be observed: start
 * {@code GET /sleep?seconds=8}, delete the pod, expect HTTP 200. Tomcat graceful
 * shutdown waits for this in-flight work after SIGTERM (after preStop).
 */
@RestController
class LifecycleController {

	private static final Logger log = LoggerFactory.getLogger(LifecycleController.class);

	static final double MAX_SLEEP_SECONDS = 60;

	@GetMapping("/sleep")
	ResponseEntity<Map<String, Object>> sleep(
			@RequestParam(name = "seconds", defaultValue = "5") double seconds)
			throws InterruptedException {
		double bounded = Math.max(0, Math.min(MAX_SLEEP_SECONDS, seconds));
		log.info("sleep start seconds={}", bounded);
		long startNanos = System.nanoTime();
		Thread.sleep(Duration.ofMillis(Math.round(bounded * 1000)));
		double elapsed = (System.nanoTime() - startNanos) / 1_000_000_000.0;
		log.info("sleep done elapsed={}", elapsed);
		return ResponseEntity.ok(Map.of(
				"slept", elapsed,
				"requestedSeconds", seconds));
	}

}
