# Simple JSON serialization/deserialization utilities
# No external dependencies required

"""
    parse_json(str::String)

Parse a JSON string into Julia data structures.
Supports objects (Dict), arrays, strings, numbers, booleans, and null.

# Returns
- Dict, Array, String, Number, Bool, or nothing

# Example
```julia
data = parse_json("{\"key\": \"value\", \"count\": 42}")
# Dict("key" => "value", "count" => 42)
```
"""
function parse_json(str::String)
    pos = 1
    result, _ = _parse_json_value(str, pos)
    return result
end

"""
    parse_json_file(filepath::String)

Parse a JSON file into Julia data structures.

# Example
```julia
data = parse_json_file("results/benchmark.json")
```
"""
function parse_json_file(filepath::String)
    if !isfile(filepath)
        error("File not found: $filepath")
    end
    json_str = read(filepath, String)
    return parse_json(json_str)
end

# Internal parsing functions
function _parse_json_value(str::String, pos::Int)
    # Skip whitespace
    pos = _skip_whitespace(str, pos)

    if pos > length(str)
        error("Unexpected end of JSON")
    end

    c = str[pos]

    if c == '{'
        return _parse_json_object(str, pos)
    elseif c == '['
        return _parse_json_array(str, pos)
    elseif c == '"'
        return _parse_json_string(str, pos)
    elseif c == 't'
        return _parse_json_literal(str, pos, "true", true)
    elseif c == 'f'
        return _parse_json_literal(str, pos, "false", false)
    elseif c == 'n'
        return _parse_json_literal(str, pos, "null", nothing)
    elseif c == '-' || isdigit(c)
        return _parse_json_number(str, pos)
    else
        error("Unexpected character at position $pos: '$c'")
    end
end

function _skip_whitespace(str::String, pos::Int)
    while pos <= length(str) && str[pos] in (' ', '\t', '\n', '\r')
        pos += 1
    end
    return pos
end

function _parse_json_object(str::String, pos::Int)
    result = Dict{String, Any}()
    pos += 1  # Skip '{'
    pos = _skip_whitespace(str, pos)

    if pos <= length(str) && str[pos] == '}'
        return result, pos + 1
    end

    while true
        # Parse key
        pos = _skip_whitespace(str, pos)
        if pos > length(str) || str[pos] != '"'
            error("Expected string key at position $pos")
        end

        key, pos = _parse_json_string(str, pos)

        # Parse colon
        pos = _skip_whitespace(str, pos)
        if pos > length(str) || str[pos] != ':'
            error("Expected ':' at position $pos")
        end
        pos += 1

        # Parse value
        value, pos = _parse_json_value(str, pos)
        result[key] = value

        # Check for comma or end
        pos = _skip_whitespace(str, pos)
        if pos > length(str)
            error("Unexpected end of object")
        end

        if str[pos] == '}'
            return result, pos + 1
        elseif str[pos] == ','
            pos += 1
        else
            error("Expected ',' or '}' at position $pos")
        end
    end
end

function _parse_json_array(str::String, pos::Int)
    result = Any[]
    pos += 1  # Skip '['
    pos = _skip_whitespace(str, pos)

    if pos <= length(str) && str[pos] == ']'
        return result, pos + 1
    end

    while true
        # Parse value
        value, pos = _parse_json_value(str, pos)
        push!(result, value)

        # Check for comma or end
        pos = _skip_whitespace(str, pos)
        if pos > length(str)
            error("Unexpected end of array")
        end

        if str[pos] == ']'
            return result, pos + 1
        elseif str[pos] == ','
            pos += 1
        else
            error("Expected ',' or ']' at position $pos")
        end
    end
end

function _parse_json_string(str::String, pos::Int)
    pos += 1  # Skip opening quote
    start_pos = pos
    result = IOBuffer()

    while pos <= length(str)
        c = str[pos]

        if c == '"'
            return String(take!(result)), pos + 1
        elseif c == '\\'
            pos += 1
            if pos > length(str)
                error("Unexpected end of string")
            end

            escape_char = str[pos]
            if escape_char == 'n'
                write(result, '\n')
            elseif escape_char == 't'
                write(result, '\t')
            elseif escape_char == 'r'
                write(result, '\r')
            elseif escape_char == '"'
                write(result, '"')
            elseif escape_char == '\\'
                write(result, '\\')
            elseif escape_char == '/'
                write(result, '/')
            else
                write(result, escape_char)
            end
            pos += 1
        else
            write(result, c)
            pos += 1
        end
    end

    error("Unterminated string")
end

function _parse_json_number(str::String, pos::Int)
    start_pos = pos

    # Handle negative
    if pos <= length(str) && str[pos] == '-'
        pos += 1
    end

    # Parse integer part
    if pos > length(str) || !isdigit(str[pos])
        error("Invalid number at position $start_pos")
    end

    while pos <= length(str) && isdigit(str[pos])
        pos += 1
    end

    # Parse decimal part
    has_decimal = false
    if pos <= length(str) && str[pos] == '.'
        has_decimal = true
        pos += 1

        if pos > length(str) || !isdigit(str[pos])
            error("Invalid decimal number at position $start_pos")
        end

        while pos <= length(str) && isdigit(str[pos])
            pos += 1
        end
    end

    # Parse exponent
    if pos <= length(str) && (str[pos] == 'e' || str[pos] == 'E')
        has_decimal = true
        pos += 1

        if pos <= length(str) && (str[pos] == '+' || str[pos] == '-')
            pos += 1
        end

        if pos > length(str) || !isdigit(str[pos])
            error("Invalid exponent at position $start_pos")
        end

        while pos <= length(str) && isdigit(str[pos])
            pos += 1
        end
    end

    num_str = str[start_pos:pos-1]
    num = has_decimal ? parse(Float64, num_str) : parse(Int, num_str)

    return num, pos
end

function _parse_json_literal(str::String, pos::Int, literal::String, value)
    end_pos = pos + length(literal) - 1

    if end_pos > length(str) || str[pos:end_pos] != literal
        error("Expected '$literal' at position $pos")
    end

    return value, end_pos + 1
end

"""
    write_json(io::IO, data, indent::Int=0)

Write data to IO as formatted JSON.
Supports Dict, Array, String, Number, Bool, and nothing.

# Arguments
- `io` - IO stream to write to
- `data` - Data to serialize
- `indent` - Current indentation level (for pretty printing)

# Example
```julia
open("output.json", "w") do io
    write_json(io, Dict("key" => "value"))
end
```
"""
function write_json(io::IO, data, indent::Int=0)
    prefix = "  "^indent

    if data === nothing
        print(io, "null")
    elseif isa(data, Array)
        println(io, "[")
        for (i, item) in enumerate(data)
            print(io, prefix, "  ")
            write_json(io, item, indent + 1)
            if i < length(data)
                println(io, ",")
            else
                println(io)
            end
        end
        print(io, prefix, "]")
    elseif isa(data, Dict)
        println(io, "{")
        keys_list = collect(keys(data))
        for (i, key) in enumerate(keys_list)
            print(io, prefix, "  \"", key, "\": ")
            write_json(io, data[key], indent + 1)
            if i < length(keys_list)
                println(io, ",")
            else
                println(io)
            end
        end
        print(io, prefix, "}")
    elseif isa(data, String)
        print(io, "\"", escape_string(data), "\"")
    elseif isa(data, Number)
        print(io, data)
    elseif isa(data, Bool)
        print(io, data ? "true" : "false")
    elseif isa(data, Symbol)
        print(io, "\"", string(data), "\"")
    else
        print(io, "\"", string(data), "\"")
    end
end

"""
    write_json_file(filepath::String, data)

Write data to a JSON file with pretty formatting.

# Example
```julia
write_json_file("results.json", Dict("status" => "success"))
```
"""
function write_json_file(filepath::String, data)
    mkpath(dirname(filepath))
    open(filepath, "w") do io
        write_json(io, data, 0)
        println(io)  # Add final newline
    end
end

"""
    to_json_string(data)

Convert data to a JSON string.

# Example
```julia
json_str = to_json_string(Dict("count" => 42))
```
"""
function to_json_string(data)
    io = IOBuffer()
    write_json(io, data, 0)
    return String(take!(io))
end
