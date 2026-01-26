//// Example: Using viva_telemetry/bench
////
//// Run: gleam run -m viva_telemetry/examples/bench_example

import gleam/io
import gleam/list
import viva_telemetry/bench

pub fn main() {
  io.println("=== viva_telemetry/bench Demo ===\n")

  // Simple benchmark
  io.println("--- Single Benchmark ---")
  let result1 = bench.run("list.range(1, 1000)", fn() { list.range(1, 1000) })
  bench.print(result1)

  // Compare two implementations
  io.println("\n--- Comparison ---")
  let fib_recursive_result =
    bench.run("fib_recursive(20)", fn() { fib_recursive(20) })
  let fib_iterative_result =
    bench.run("fib_iterative(20)", fn() { fib_iterative(20) })

  bench.print(fib_recursive_result)
  bench.print(fib_iterative_result)

  let cmp = bench.compare(fib_recursive_result, fib_iterative_result)
  bench.print_comparison(cmp)

  // Multiple benchmarks - run individually for different return types
  io.println("\n--- Multiple Benchmarks (Markdown) ---")
  let cfg = bench.config(5, 50)

  let map_result =
    bench.run_with_config(
      "list.map",
      fn() { list.map(list.range(1, 100), fn(x) { x * 2 }) },
      cfg,
    )

  let filter_result =
    bench.run_with_config(
      "list.filter",
      fn() { list.filter(list.range(1, 100), fn(x) { x % 2 == 0 }) },
      cfg,
    )

  let fold_result =
    bench.run_with_config(
      "list.fold",
      fn() { list.fold(list.range(1, 100), 0, fn(acc, x) { acc + x }) },
      cfg,
    )

  io.println(bench.to_markdown_table([map_result, filter_result, fold_result]))

  // JSON export
  io.println("\n--- JSON Export ---")
  io.println(bench.to_json_string(result1))

  io.println("\n=== Demo completed! ===")
}

// Fibonacci implementations for comparison
fn fib_recursive(n: Int) -> Int {
  case n {
    0 -> 0
    1 -> 1
    _ -> fib_recursive(n - 1) + fib_recursive(n - 2)
  }
}

fn fib_iterative(n: Int) -> Int {
  fib_iter(n, 0, 1)
}

fn fib_iter(n: Int, a: Int, b: Int) -> Int {
  case n {
    0 -> a
    _ -> fib_iter(n - 1, b, a + b)
  }
}
