package com.example.demo;

import jakarta.servlet.http.HttpServletRequest;

import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.regex.Pattern;

/**
 * Original caller for a trace. Incoming W3C baggage wins so a later hop does
 * not replace the person who started the request. {@code X-End-User} is only
 * the edge input (a demo header, or a gateway copy of a verified token claim).
 */
final class EndUserResolver {

	static final String BAGGAGE_KEY = "enduser.id";

	static final String HEADER = "X-End-User";

	private static final Pattern ID = Pattern.compile("[A-Za-z0-9._@+-]{1,128}");

	private EndUserResolver() {
	}

	static String resolve(HttpServletRequest request) {
		String fromBaggage = fromBaggageHeader(request.getHeader("baggage"));
		if (fromBaggage != null) {
			return fromBaggage;
		}
		return sanitize(request.getHeader(HEADER));
	}

	static String fromBaggageHeader(String header) {
		if (header == null || header.isBlank()) {
			return null;
		}
		for (String member : header.split(",")) {
			String part = member.trim();
			int eq = part.indexOf('=');
			if (eq <= 0) {
				continue;
			}
			if (!BAGGAGE_KEY.equals(part.substring(0, eq).trim())) {
				continue;
			}
			String raw = part.substring(eq + 1).trim();
			int semi = raw.indexOf(';');
			if (semi >= 0) {
				raw = raw.substring(0, semi).trim();
			}
			try {
				return sanitize(URLDecoder.decode(raw, StandardCharsets.UTF_8));
			}
			catch (IllegalArgumentException ex) {
				return null;
			}
		}
		return null;
	}

	static String sanitize(String value) {
		if (value == null) {
			return null;
		}
		String trimmed = value.trim();
		if (!ID.matcher(trimmed).matches()) {
			return null;
		}
		return trimmed;
	}

}
