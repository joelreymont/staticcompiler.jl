# Constants and configuration values used across StaticCompiler

# Binary size thresholds (bytes)
const BINARY_SIZE_SMALL = 50_000      # 50 KB - threshold for "small" binaries
const BINARY_SIZE_MEDIUM = 100_000    # 100 KB - threshold for "medium" binaries
const BINARY_SIZE_LARGE = 500_000     # 500 KB - threshold for "large" binaries

# Performance thresholds
const PERFORMANCE_THRESHOLD_FAST_NS = 50_000   # 50 μs - fast execution threshold
const PERFORMANCE_THRESHOLD_SLOW_NS = 100_000  # 100 μs - slow execution threshold

# Regression detection
const DEFAULT_REGRESSION_THRESHOLD_PCT = 5.0    # 5% - default performance regression threshold
const DEFAULT_IMPROVEMENT_THRESHOLD_PCT = 5.0   # 5% - minimum improvement to continue PGO iterations

# Benchmark configuration
const DEFAULT_BENCHMARK_SAMPLES = 100           # Number of benchmark samples
const DEFAULT_WARMUP_SAMPLES = 10               # Number of warmup iterations
const DEFAULT_MAX_BENCHMARK_TIME_SECONDS = 60   # Maximum time for benchmarking

# PGO configuration
const DEFAULT_PGO_ITERATIONS = 3                # Default number of PGO iterations
const DEFAULT_PGO_BENCHMARK_SAMPLES = 100       # Samples per PGO iteration

# Cache configuration
const DEFAULT_CACHE_MAX_AGE_DAYS = 30           # Default cache expiration time
const DEFAULT_CACHE_MAX_SIZE_MB = 1000          # Default maximum cache size

# CI/CD thresholds
const DEFAULT_CI_PERFORMANCE_BUDGET_MS = 1000   # 1 second - default performance budget
const DEFAULT_CI_SIZE_BUDGET_KB = 10240         # 10 MB - default size budget

# Analysis scoring weights
const SCORE_WEIGHT_PER_MODULE = 5.0             # Points per module in dependency analysis
const SCORE_WEIGHT_PER_FUNCTION = 0.5           # Points per function in bloat analysis
const SCORE_PENALTY_MAX_FUNCTIONS = 30.0        # Maximum score penalty for function count

# Size estimation constants
const BASE_RUNTIME_SIZE_KB = 25.0               # Base runtime overhead in KB
const ESTIMATED_FUNCTION_SIZE_BYTES = 0.5       # Estimated size per function (some inlined)

# Smart optimization thresholds
const SMART_OPT_SMALL_THRESHOLD = BINARY_SIZE_SMALL     # Threshold for "small" classification
const SMART_OPT_MEDIUM_THRESHOLD = BINARY_SIZE_MEDIUM   # Threshold for "medium" classification
const SMART_OPT_LARGE_THRESHOLD = BINARY_SIZE_LARGE     # Threshold for "large" classification

# Preset defaults
const PRESET_MIN_PERFORMANCE_SCORE = 75.0       # Minimum acceptable performance score
