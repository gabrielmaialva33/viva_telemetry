.PHONY: build test bench docs clean format check

# Build the project
build:
	gleam build

# Run all tests
test:
	gleam test

# Run benchmarks
bench:
	gleam run -m viva_telemetry/examples/bench_example

# Run logging example
log:
	gleam run -m viva_telemetry/examples/log_example

# Run metrics example
metrics:
	gleam run -m viva_telemetry/examples/metrics_example

# Generate documentation
docs:
	gleam docs build

# Format code
format:
	gleam format src test

# Check formatting
check:
	gleam format --check src test

# Clean build artifacts
clean:
	rm -rf build

# Publish to Hex
publish:
	gleam publish

# All examples
examples: log metrics bench
