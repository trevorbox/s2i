package com.example.demo;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.stereotype.Component;

import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Fails the readiness group when the preStop drain flag exists, without failing
 * liveness. {@code touch} does not change probes by itself; {@code /ready} must
 * see this file so kubelet can mark the pod not-ready while the process still
 * serves in-flight requests during the EDS wait.
 */
@Component
class DrainFlagHealthIndicator implements HealthIndicator {

	private final Path flagFile;

	DrainFlagHealthIndicator(@Value("${app.drain-flag-file:/tmp/unhealthy}") String flagFile) {
		this.flagFile = Path.of(flagFile);
	}

	boolean isSet() {
		return Files.exists(flagFile);
	}

	Path flagFile() {
		return flagFile;
	}

	@Override
	public Health health() {
		if (isSet()) {
			return Health.outOfService().withDetail("flagFile", flagFile.toString()).build();
		}
		return Health.up().build();
	}

}
