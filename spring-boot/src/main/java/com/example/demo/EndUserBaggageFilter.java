package com.example.demo;

import io.micrometer.tracing.BaggageInScope;
import io.micrometer.tracing.Tracer;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Puts {@code enduser.id} into the current trace baggage so child spans and
 * outbound calls keep the original caller. The HTTP server span is tagged
 * separately, from the request, when that observation starts.
 */
@Component
class EndUserBaggageFilter extends OncePerRequestFilter {

	private final ObjectProvider<Tracer> tracer;

	EndUserBaggageFilter(ObjectProvider<Tracer> tracer) {
		this.tracer = tracer;
	}

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {
		if (TracingConfiguration.isProbe(request.getRequestURI())) {
			filterChain.doFilter(request, response);
			return;
		}
		Tracer current = this.tracer.getIfAvailable();
		String user = EndUserResolver.resolve(request);
		if (current == null || user == null) {
			filterChain.doFilter(request, response);
			return;
		}
		try (BaggageInScope scope = current.createBaggageInScope(EndUserResolver.BAGGAGE_KEY, user)) {
			filterChain.doFilter(request, response);
		}
	}

}
