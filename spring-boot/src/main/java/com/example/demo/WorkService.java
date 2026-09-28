package com.example.demo;

import io.micrometer.tracing.Baggage;
import io.micrometer.tracing.Span;
import io.micrometer.tracing.Tracer;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * Nested spans for one request so a mesh trace shows the routines under the
 * HTTP hop. Span tags stay off Micrometer meters: {@code enduser.id} and
 * {@code order.sku} would explode Prometheus label cardinality.
 */
@Service
class WorkService {

	static final String DEFAULT_SKU = "widget";

	private static final String CODE_NAMESPACE = "com.example.demo.WorkService";

	private final Tracer tracer;

	WorkService(Tracer tracer) {
		this.tracer = tracer;
	}

	Map<String, Object> perform(String sku) {
		String normalized = normalizeSku(sku);
		Span current = this.tracer.currentSpan();
		String traceId = current == null ? null : current.context().traceId();
		String spanId = current == null ? null : current.context().spanId();

		inSpan("work.authorize", "authorize");
		String resolvedSku = inSpan("work.lookup-order", "lookupOrder", Map.of("order.sku", normalized),
				() -> normalized);
		int price = inSpan("work.price", "price", Map.of("order.sku", resolvedSku),
				() -> priceFor(resolvedSku));

		Map<String, Object> body = new LinkedHashMap<>();
		body.put("sku", resolvedSku);
		body.put("price", price);
		body.put("steps", List.of("authorize", "lookup-order", "price"));
		String user = currentEndUser();
		if (user != null) {
			body.put(EndUserResolver.BAGGAGE_KEY, user);
		}
		if (traceId != null && !traceId.isBlank()) {
			body.put("traceId", traceId);
		}
		if (spanId != null && !spanId.isBlank()) {
			body.put("spanId", spanId);
		}
		return body;
	}

	static String normalizeSku(String sku) {
		if (sku == null) {
			return DEFAULT_SKU;
		}
		String trimmed = sku.trim();
		if (!trimmed.matches("[A-Za-z0-9._-]{1,64}")) {
			return DEFAULT_SKU;
		}
		return trimmed;
	}

	static int priceFor(String sku) {
		return 1000 + Math.floorMod(sku.hashCode(), 500);
	}

	private void inSpan(String spanName, String functionName) {
		inSpan(spanName, functionName, Map.of(), () -> null);
	}

	private <T> T inSpan(String spanName, String functionName, Map<String, String> tags, Supplier<T> work) {
		Span span = this.tracer.nextSpan().name(spanName);
		span.tag("code.function.name", functionName);
		span.tag("code.namespace", CODE_NAMESPACE);
		tags.forEach(span::tag);
		tagEndUser(span);
		span.start();
		try (Tracer.SpanInScope scope = this.tracer.withSpan(span)) {
			return work.get();
		}
		catch (RuntimeException ex) {
			span.error(ex);
			throw ex;
		}
		finally {
			span.end();
		}
	}

	private void tagEndUser(Span span) {
		String user = currentEndUser();
		if (user != null) {
			span.tag(EndUserResolver.BAGGAGE_KEY, user);
		}
	}

	private String currentEndUser() {
		Baggage baggage = this.tracer.getBaggage(EndUserResolver.BAGGAGE_KEY);
		if (baggage == null) {
			return null;
		}
		String value = baggage.get();
		if (value == null || value.isBlank()) {
			return null;
		}
		return value;
	}

}
