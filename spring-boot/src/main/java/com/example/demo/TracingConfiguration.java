package com.example.demo;

import io.micrometer.common.KeyValue;
import io.micrometer.observation.ObservationFilter;
import io.micrometer.observation.ObservationPredicate;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.server.observation.ServerRequestObservationContext;

/**
 * Keeps kubelet probes and actuator scrapes out of the trace backend, and
 * copies the original caller onto the HTTP server span.
 */
@Configuration
class TracingConfiguration {

	@Bean
	ObservationPredicate skipProbeObservations() {
		return (name, context) -> {
			if (context instanceof ServerRequestObservationContext server) {
				return !isProbe(server.getCarrier().getRequestURI());
			}
			return true;
		};
	}

	@Bean
	ObservationFilter endUserSpanAttribute() {
		return context -> {
			if (context instanceof ServerRequestObservationContext server) {
				String user = EndUserResolver.resolve(server.getCarrier());
				if (user != null) {
					context.addHighCardinalityKeyValue(KeyValue.of(EndUserResolver.BAGGAGE_KEY, user));
				}
			}
			return context;
		};
	}

	static boolean isProbe(String uri) {
		if (uri == null || uri.isEmpty()) {
			return false;
		}
		return "/live".equals(uri) || "/ready".equals(uri) || uri.startsWith("/actuator");
	}

}
