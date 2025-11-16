# Progress bar support for long-running operations
# Provides visual feedback for compilation, benchmarking, and analysis

using Printf

"""
    ProgressBar

Simple progress bar for terminal output.

# Fields
- `total::Int` - Total number of items
- `current::Int` - Current item count
- `description::String` - Operation description
- `width::Int` - Width of progress bar in characters
- `show_percentage::Bool` - Show percentage complete
- `show_eta::Bool` - Show estimated time remaining
- `start_time::Float64` - Start time for ETA calculation
"""
mutable struct ProgressBar
    total::Int
    current::Int
    description::String
    width::Int
    show_percentage::Bool
    show_eta::Bool
    start_time::Float64

    function ProgressBar(total::Int; description::String="Progress", width::Int=40, show_percentage::Bool=true, show_eta::Bool=true)
        new(total, 0, description, width, show_percentage, show_eta, time())
    end
end

"""
    update!(pb::ProgressBar, n::Int=1)

Update progress bar by n items.

# Arguments
- `pb` - ProgressBar to update
- `n` - Number of items to add (default: 1)

# Example
```julia
pb = ProgressBar(100, description="Processing")
for i in 1:100
    # Do work
    update!(pb)
end
finish!(pb)
```
"""
function update!(pb::ProgressBar, n::Int=1)
    pb.current = min(pb.current + n, pb.total)
    render(pb)
end

"""
    set!(pb::ProgressBar, value::Int)

Set progress bar to specific value.

# Arguments
- `pb` - ProgressBar to update
- `value` - Absolute value to set

# Example
```julia
pb = ProgressBar(100)
set!(pb, 50)  # Set to 50%
```
"""
function set!(pb::ProgressBar, value::Int)
    pb.current = min(value, pb.total)
    render(pb)
end

"""
    finish!(pb::ProgressBar)

Mark progress bar as complete.

# Arguments
- `pb` - ProgressBar to finish

# Example
```julia
pb = ProgressBar(100)
# ... work ...
finish!(pb)
```
"""
function finish!(pb::ProgressBar)
    pb.current = pb.total
    render(pb, final=true)
    println()  # Newline after completion
end

"""
    render(pb::ProgressBar; final::Bool=false)

Render progress bar to terminal.

# Arguments
- `pb` - ProgressBar to render
- `final` - If true, this is the final render (don't overwrite)
"""
function render(pb::ProgressBar; final::Bool=false)
    # Check if logging is set to SILENT
    if get_log_config().level == SILENT
        return
    end

    # Calculate progress
    percent = pb.total > 0 ? (pb.current / pb.total) * 100 : 0.0
    filled = Int(round((pb.current / pb.total) * pb.width))
    empty = pb.width - filled

    # Build progress bar string
    bar = "█"^filled * "░"^empty

    # Build status string
    status_parts = String[]

    if pb.show_percentage
        push!(status_parts, @sprintf("%.1f%%", percent))
    end

    push!(status_parts, "$(pb.current)/$(pb.total)")

    if pb.show_eta && pb.current > 0 && pb.current < pb.total
        elapsed = time() - pb.start_time
        rate = pb.current / elapsed
        remaining = (pb.total - pb.current) / rate
        eta_str = format_duration(remaining)
        push!(status_parts, "ETA: $eta_str")
    end

    status = join(status_parts, " | ")

    # Print progress bar (overwrite previous line unless final)
    if !final
        print("\r")
    end

    print("$(pb.description): [$bar] $status")

    if !final
        flush(stdout)
    end
end

"""
    format_duration(seconds::Float64)

Format duration in seconds to human-readable string.

# Arguments
- `seconds` - Duration in seconds

# Returns
- Formatted string (e.g., "1m 30s", "45s", "2h 15m")
"""
function format_duration(seconds::Float64)
    if seconds < 60
        return @sprintf("%ds", Int(round(seconds)))
    elseif seconds < 3600
        mins = Int(floor(seconds / 60))
        secs = Int(round(seconds % 60))
        return @sprintf("%dm %ds", mins, secs)
    else
        hours = Int(floor(seconds / 3600))
        mins = Int(floor((seconds % 3600) / 60))
        return @sprintf("%dh %dm", hours, mins)
    end
end

"""
    with_progress(f::Function, total::Int; description::String="Progress", kwargs...)

Execute function with automatic progress bar.

# Arguments
- `f` - Function that takes a progress bar as argument
- `total` - Total number of items
- `description` - Operation description
- `kwargs` - Additional ProgressBar arguments

# Example
```julia
with_progress(100, description="Processing items") do pb
    for i in 1:100
        # Do work
        update!(pb)
    end
end
```
"""
function with_progress(f::Function, total::Int; description::String="Progress", kwargs...)
    pb = ProgressBar(total; description=description, kwargs...)

    try
        f(pb)
        finish!(pb)
    catch e
        println()  # Ensure we don't corrupt the terminal
        rethrow(e)
    end
end

"""
    progress_map(f::Function, items; description::String="Processing", show_items::Bool=false)

Map function over items with progress bar.

# Arguments
- `f` - Function to apply to each item
- `items` - Collection to iterate over
- `description` - Progress bar description
- `show_items` - Show item names in progress bar

# Returns
- Vector of results

# Example
```julia
results = progress_map(x -> x^2, 1:100, description="Squaring numbers")
```
"""
function progress_map(f::Function, items; description::String="Processing", show_items::Bool=false)
    results = Vector{Any}(undef, length(items))

    with_progress(length(items), description=description) do pb
        for (i, item) in enumerate(items)
            if show_items
                item_desc = "$description: $item"
                pb.description = item_desc
            end

            results[i] = f(item)
            update!(pb)
        end
    end

    return results
end

"""
    IndeterminateProgress

Progress indicator for operations with unknown duration.

# Fields
- `description::String` - Operation description
- `spinner_chars::Vector{Char}` - Characters for spinner animation
- `current_frame::Int` - Current animation frame
- `start_time::Float64` - Start time
"""
mutable struct IndeterminateProgress
    description::String
    spinner_chars::Vector{Char}
    current_frame::Int
    start_time::Float64

    function IndeterminateProgress(description::String="Working")
        new(description, ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'], 1, time())
    end
end

"""
    tick!(ip::IndeterminateProgress)

Advance indeterminate progress indicator.

# Arguments
- `ip` - IndeterminateProgress to update
"""
function tick!(ip::IndeterminateProgress)
    if get_log_config().level == SILENT
        return
    end

    elapsed = time() - ip.start_time
    spinner = ip.spinner_chars[ip.current_frame]

    print("\r$(ip.description) $spinner $(format_duration(elapsed))")
    flush(stdout)

    ip.current_frame = (ip.current_frame % length(ip.spinner_chars)) + 1
end

"""
    stop!(ip::IndeterminateProgress)

Stop indeterminate progress indicator.

# Arguments
- `ip` - IndeterminateProgress to stop
"""
function stop!(ip::IndeterminateProgress)
    if get_log_config().level == SILENT
        return
    end

    elapsed = time() - ip.start_time
    print("\r$(ip.description) ✓ $(format_duration(elapsed))\n")
end

"""
    with_spinner(f::Function, description::String="Working")

Execute function with spinner animation.

# Arguments
- `f` - Function to execute
- `description` - Operation description

# Example
```julia
result = with_spinner("Compiling") do
    # Long-running operation
    compile_executable(func, types, path, name)
end
```
"""
function with_spinner(f::Function, description::String="Working")
    ip = IndeterminateProgress(description)

    # Start background task to update spinner
    spinner_task = @task begin
        while true
            tick!(ip)
            sleep(0.1)
        end
    end

    schedule(spinner_task)

    try
        result = f()
        stop!(ip)
        return result
    catch e
        println()  # Clear spinner
        rethrow(e)
    finally
        # Stop spinner task
        try
            Base.throwto(spinner_task, InterruptException())
        catch
        end
    end
end

"""
    MultiProgress

Manage multiple progress bars.

# Fields
- `bars::Vector{ProgressBar}` - Active progress bars
- `labels::Vector{String}` - Labels for each bar
"""
mutable struct MultiProgress
    bars::Vector{ProgressBar}
    labels::Vector{String}

    function MultiProgress()
        new(ProgressBar[], String[])
    end
end

"""
    add_bar!(mp::MultiProgress, total::Int, label::String)

Add a progress bar to multi-progress display.

# Arguments
- `mp` - MultiProgress manager
- `total` - Total items for this bar
- `label` - Label for this bar

# Returns
- Index of added bar
"""
function add_bar!(mp::MultiProgress, total::Int, label::String)
    pb = ProgressBar(total, description=label, width=30)
    push!(mp.bars, pb)
    push!(mp.labels, label)
    return length(mp.bars)
end

"""
    update_bar!(mp::MultiProgress, index::Int, n::Int=1)

Update specific progress bar in multi-progress display.

# Arguments
- `mp` - MultiProgress manager
- `index` - Bar index
- `n` - Number of items to add
"""
function update_bar!(mp::MultiProgress, index::Int, n::Int=1)
    if index > 0 && index <= length(mp.bars)
        update!(mp.bars[index], n)
        render_multi(mp)
    end
end

"""
    render_multi(mp::MultiProgress)

Render all progress bars in multi-progress display.

# Arguments
- `mp` - MultiProgress manager
"""
function render_multi(mp::MultiProgress)
    if get_log_config().level == SILENT
        return
    end

    # Move cursor up to start of multi-progress display
    for _ in 1:length(mp.bars)
        print("\e[1A\e[2K")  # Move up and clear line
    end
    print("\r")

    # Render each bar
    for (i, pb) in enumerate(mp.bars)
        render(pb)
        if i < length(mp.bars)
            println()
        end
    end

    flush(stdout)
end
