package com.example.demo;

import io.micrometer.tracing.BaggageInScope;
import io.micrometer.tracing.Span;
import io.micrometer.tracing.Tracer;
import io.micrometer.tracing.test.simple.SimpleSpan;
import io.micrometer.tracing.test.simple.SimpleTracer;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class WorkServiceTests {

	@Test
	void perform_opensMethodSpansAndTagsTheOriginalCaller() {
		SimpleTracer tracer = new SimpleTracer();
		WorkService service = new WorkService(tracer);

		Span parent = tracer.nextSpan().name("http").start();
		Map<String, Object> body;
		try (Tracer.SpanInScope parentScope = tracer.withSpan(parent)) {
			try (BaggageInScope scope = tracer.createBaggageInScope(EndUserResolver.BAGGAGE_KEY, "ada")) {
				body = service.perform("desk");
			}
		}
		finally {
			parent.end();
		}

		assertThat(body.get("sku")).isEqualTo("desk");
		assertThat(body.get("price")).isEqualTo(WorkService.priceFor("desk"));
		assertThat(body.get(EndUserResolver.BAGGAGE_KEY)).isEqualTo("ada");
		assertThat(tracer.getSpans()).extracting(SimpleSpan::getName)
				.containsExactly("http", "work.authorize", "work.lookup-order", "work.price");
		assertThat(span(tracer, "work.lookup-order").getTags()).containsEntry("order.sku", "desk")
				.containsEntry("code.function.name", "lookupOrder")
				.containsEntry(EndUserResolver.BAGGAGE_KEY, "ada");
		assertThat(span(tracer, "work.authorize").getTags()).containsEntry(EndUserResolver.BAGGAGE_KEY, "ada");
	}

	@Test
	void perform_omitsEndUserWhenBaggageIsAbsent() {
		SimpleTracer tracer = new SimpleTracer();
		Map<String, Object> body = new WorkService(tracer).perform("nope sku");

		assertThat(body.get("sku")).isEqualTo(WorkService.DEFAULT_SKU);
		assertThat(body).doesNotContainKey(EndUserResolver.BAGGAGE_KEY);
		assertThat(span(tracer, "work.price").getTags()).doesNotContainKey(EndUserResolver.BAGGAGE_KEY);
	}

	private static SimpleSpan span(SimpleTracer tracer, String name) {
		return tracer.getSpans().stream()
				.filter(span -> name.equals(span.getName()))
				.findFirst()
				.orElseThrow();
	}

}
