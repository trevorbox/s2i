package com.example.demo;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class EndUserResolverTest {

	@Test
	void baggageMemberWinsOverHeader() {
		assertThat(EndUserResolver.fromBaggageHeader("other=x, enduser.id=grace;screen=1")).isEqualTo("grace");
	}

	@Test
	void decodesBaggageValue() {
		assertThat(EndUserResolver.fromBaggageHeader("enduser.id=ada%40example.com")).isEqualTo("ada@example.com");
	}

	@Test
	void rejectsValuesThatWouldBreakTheBaggageHeader() {
		assertThat(EndUserResolver.sanitize("not a user")).isNull();
		assertThat(EndUserResolver.sanitize("a,b")).isNull();
		assertThat(EndUserResolver.sanitize("")).isNull();
	}

	@Test
	void probePathsAreExcludedFromTracing() {
		assertThat(TracingConfiguration.isProbe("/live")).isTrue();
		assertThat(TracingConfiguration.isProbe("/ready")).isTrue();
		assertThat(TracingConfiguration.isProbe("/actuator/prometheus")).isTrue();
		assertThat(TracingConfiguration.isProbe("/api/work")).isFalse();
	}

}
