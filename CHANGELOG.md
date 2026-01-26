# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-01-26

### Added
- **Logging**: Structured logging with RFC 5424 levels
  - Console, JSON, and File handlers
  - Context propagation
  - Lazy evaluation for performance
  - Sampling for high-volume logs
- **Metrics**: Counter, Gauge, and Histogram types
  - ETS-backed storage
  - Prometheus export format
  - BEAM memory tracking
- **Benchmarking**: Statistical benchmarks
  - Warmup and sample collection
  - Mean, stddev, percentiles (p50, p95, p99)
  - 95% confidence intervals
  - JSON/Markdown export
  - Comparison with speedup calculation

### Infrastructure
- CI/CD with auto-publish to Hex on tags
- 32 tests covering all modules
- Examples for each module
