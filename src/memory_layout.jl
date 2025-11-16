# Memory layout and struct optimization analysis

"""
Memory layout analysis for a type
"""
struct MemoryLayoutReport
    type_name::String
    total_size::Int        # bytes
    alignment::Int         # bytes
    padding_bytes::Int     # wasted bytes
    field_info::Vector{Tuple{Symbol, Int, Int}}  # (name, offset, size)
    suggested_order::Vector{Symbol}
    potential_savings::Int  # bytes that could be saved
    cache_efficiency::Float64  # 0-100
end

"""
    analyze_memory_layout(T::Type; verbose=true)

Analyze the memory layout of a struct type.

Identifies:
- Field alignment and padding
- Opportunities to reorder fields
- Cache line utilization
- Memory wasted due to padding

# Example
```julia
struct MyData
    a::Int8      # 1 byte
    b::Int64     # 8 bytes
    c::Int8      # 1 byte
end

report = analyze_memory_layout(MyData)
# Will suggest reordering to minimize padding
```
"""
function analyze_memory_layout(T::Type; verbose=true)
    if !isconcretetype(T)
        if verbose
            println("⚠️  Type $T is not a concrete type")
        end
        return nothing
    end

    if isprimitivetype(T)
        if verbose
            println("ℹ️  Type $T is a primitive type (no layout to optimize)")
        end
        return nothing
    end

    type_name = string(T)
    total_size = sizeof(T)
    alignment = Base.datatype_alignment(T)

    # Get field information
    field_info = Tuple{Symbol, Int, Int}[]
    field_types = fieldtypes(T)
    field_names = fieldnames(T)

    current_offset = 0
    padding_bytes = 0

    for (i, (fname, ftype)) in enumerate(zip(field_names, field_types))
        field_size = sizeof(ftype)
        field_align = Base.datatype_alignment(ftype)

        # Calculate padding before this field
        padding = (field_align - (current_offset % field_align)) % field_align
        padding_bytes += padding
        current_offset += padding

        # Store field info (offset after padding)
        push!(field_info, (fname, current_offset, field_size))

        current_offset += field_size
    end

    # Add final padding to struct
    final_padding = (alignment - (current_offset % alignment)) % alignment
    padding_bytes += final_padding

    # Suggest optimal field ordering (largest to smallest for minimal padding)
    field_sizes = [(fname, sizeof(ftype)) for (fname, ftype) in zip(field_names, field_types)]
    sort!(field_sizes, by=x->x[2], rev=true)
    suggested_order = [fname for (fname, _) in field_sizes]

    # Calculate potential savings
    # Recompute layout with suggested order
    optimized_offset = 0
    optimized_padding = 0

    for fname in suggested_order
        idx = findfirst(==(fname), field_names)
        ftype = field_types[idx]

        field_size = sizeof(ftype)
        field_align = Base.datatype_alignment(ftype)

        padding = (field_align - (optimized_offset % field_align)) % field_align
        optimized_padding += padding
        optimized_offset += padding + field_size
    end

    optimized_final = (alignment - (optimized_offset % alignment)) % alignment
    optimized_padding += optimized_final

    potential_savings = padding_bytes - optimized_padding

    # Calculate cache efficiency (64-byte cache line)
    cache_line_size = 64
    cache_lines_used = ceil(Int, total_size / cache_line_size)
    cache_efficiency = (total_size / (cache_lines_used * cache_line_size)) * 100.0

    report = MemoryLayoutReport(
        type_name,
        total_size,
        alignment,
        padding_bytes,
        field_info,
        suggested_order,
        potential_savings,
        cache_efficiency
    )

    if verbose
        print_memory_layout_report(report, field_names)
    end

    return report
end

function print_memory_layout_report(report::MemoryLayoutReport, original_order::Tuple)
    println("\n" * "="^70)
    println("MEMORY LAYOUT ANALYSIS: $(report.type_name)")
    println("="^70)

    println("\n📊 SIZE: $(report.total_size) bytes")
    println("📏 ALIGNMENT: $(report.alignment) bytes")
    println("📦 PADDING: $(report.padding_bytes) bytes ($(round(report.padding_bytes/report.total_size*100, digits=1))% wasted)")
    println("🔄 CACHE EFFICIENCY: $(round(report.cache_efficiency, digits=1))%")

    println("\n📋 CURRENT LAYOUT:")
    for (fname, offset, size) in report.field_info
        padding_marker = ""
        if offset > 0
            # Check if there's padding before this field
            prev_idx = findfirst(x -> x[1] == fname, report.field_info)
            if prev_idx !== nothing && prev_idx > 1
                prev_field = report.field_info[prev_idx-1]
                prev_end = prev_field[2] + prev_field[3]
                if offset > prev_end
                    padding_marker = " [+$(offset - prev_end) bytes padding]"
                end
            elseif prev_idx == 1 && offset > 0
                padding_marker = " [+$offset bytes padding]"
            end
        end
        println("  Offset $offset: $fname ($size bytes)$padding_marker")
    end

    if report.potential_savings > 0
        println("\n💡 OPTIMIZATION OPPORTUNITY!")
        println("   Reordering fields could save $(report.potential_savings) bytes")

        println("\n✅ SUGGESTED LAYOUT:")
        println("   struct $(report.type_name)")
        for fname in report.suggested_order
            idx = findfirst(==(fname), [f[1] for f in report.field_info])
            if idx !== nothing
                size = report.field_info[idx][3]
                # Get original type (approximation)
                type_str = size == 1 ? "Int8/UInt8" :
                          size == 2 ? "Int16/UInt16" :
                          size == 4 ? "Int32/UInt32/Float32" :
                          size == 8 ? "Int64/UInt64/Float64" : "?"
                println("       $fname::$type_str  # $size bytes")
            end
        end
        println("   end")

        println("\n   This would reduce total size from $(report.total_size) to $(report.total_size - report.potential_savings) bytes")
    else
        if all(original_order .== report.suggested_order)
            println("\n✅ LAYOUT IS OPTIMAL!")
            println("   Fields are already ordered for minimal padding")
        else
            println("\n✅ NO SAVINGS POSSIBLE")
            println("   Current layout is already minimal for this field configuration")
        end
    end

    cache_lines = ceil(Int, report.total_size / 64)
    if cache_lines > 1
        println("\n📍 CACHE USAGE:")
        println("   Struct spans $cache_lines cache lines (64 bytes each)")
        if report.total_size < 64
            println("   ✅ Fits in a single cache line")
        else
            println("   ⚠️  Crosses cache line boundaries (may impact performance)")
        end
    end

    println("="^70)
end

"""
    suggest_layout_optimization(T::Type)

Get suggested struct definition with optimized field order.

Returns a string with the optimized struct definition.

# Example
```julia
struct MyData
    a::Int8
    b::Int64
    c::Int8
end

println(suggest_layout_optimization(MyData))
```
"""
function suggest_layout_optimization(T::Type)
    report = analyze_memory_layout(T, verbose=false)

    if report === nothing || report.potential_savings == 0
        return "# No optimization needed for $T"
    end

    # Generate optimized struct definition
    result = "struct $(report.type_name)_Optimized\n"

    field_names = fieldnames(T)
    field_types = fieldtypes(T)

    for fname in report.suggested_order
        idx = findfirst(==(fname), field_names)
        if idx !== nothing
            ftype = field_types[idx]
            result *= "    $fname::$ftype\n"
        end
    end

    result *= "end\n\n"
    result *= "# Savings: $(report.potential_savings) bytes\n"
    result *= "# Original size: $(report.total_size) bytes\n"
    result *= "# Optimized size: $(report.total_size - report.potential_savings) bytes"

    return result
end

export MemoryLayoutReport, analyze_memory_layout, suggest_layout_optimization
