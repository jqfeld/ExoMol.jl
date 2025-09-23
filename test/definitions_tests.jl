using ExoMol
using Test
using Downloads: RequestError
using CodecBzip2: Bzip2DecompressorStream

function _fetch_wccrmt_dataset(; force=false)
    try
        return ExoMol.get_exomol_dataset("N2", "14N2", "WCCRMT"; force=force)
    catch err
        if err isa RequestError || err isa IOError
            @info "Skipping WCCRMT download-dependent tests" exception = err
            return nothing
        else
            rethrow(err)
        end
    end
end

function _state_id_symbol(states_fields)
    isempty(states_fields) && return nothing
    return Symbol(states_fields[1]["name"])
end

function _find_field_symbol(states_fields, needles)
    for field in states_fields
        name = lowercase(field["name"])
        for needle in needles
            lower_needle = lowercase(needle)
            if name == lower_needle || occursin(lower_needle, name)
                return Symbol(field["name"])
            end
        end
    end
    return nothing
end

function _write_sample_lines(src_path, dest_path, limit)
    open(dest_path, "w") do dest_io
        if endswith(src_path, ".bz2")
            open(src_path, "r") do comp_io
                stream = Bzip2DecompressorStream(comp_io)
                try
                    for (idx, line) in enumerate(eachline(stream))
                        println(dest_io, line)
                        idx >= limit && break
                    end
                finally
                    close(stream)
                end
            end
        else
            open(src_path, "r") do src_io
                for (idx, line) in enumerate(eachline(src_io))
                    println(dest_io, line)
                    idx >= limit && break
                end
            end
        end
    end
    return dest_path
end

@testset "N2 WCCRMT download and load" begin
    dataset_path = _fetch_wccrmt_dataset()

    if dataset_path === nothing
        @test_skip true
    else
        files = readdir(dataset_path)
        @test any(f -> endswith(f, ".def.json"), files)
        @test any(f -> occursin(".states", f), files)
        @test any(f -> occursin(".trans", f), files)

        def_filename = first(filter(f -> endswith(f, ".def.json"), files))
        states_filename = first(filter(f -> occursin(".states", f), files))
        trans_filename = first(filter(f -> occursin(".trans", f), files))

        sample_state_limit = 25
        sample_transition_limit = 50

        mktempdir() do sample_dir
            def_src = joinpath(dataset_path, def_filename)
            def_dest = joinpath(sample_dir, def_filename)
            cp(def_src, def_dest; force=true)

            states_src = joinpath(dataset_path, states_filename)
            states_dest_name = endswith(states_filename, ".bz2") ? replace(states_filename, ".bz2" => "") : states_filename
            states_dest = joinpath(sample_dir, states_dest_name)
            _write_sample_lines(states_src, states_dest, sample_state_limit)

            trans_src = joinpath(dataset_path, trans_filename)
            trans_dest_name = endswith(trans_filename, ".bz2") ? replace(trans_filename, ".bz2" => "") : trans_filename
            trans_dest = joinpath(sample_dir, trans_dest_name)
            _write_sample_lines(trans_src, trans_dest, sample_transition_limit)

            definitions = ExoMol.read_def_file(def_dest)
            @test haskey(definitions, "dataset")
            dataset_meta = definitions["dataset"]
            @test get(dataset_meta, "name", "") == "WCCRMT"

            @test haskey(dataset_meta, "states")
            states_meta = dataset_meta["states"]
            @test haskey(states_meta, "states_file_fields")
            states_fields = states_meta["states_file_fields"]
            @test !isempty(states_fields)
            @test all(haskey(field, "name") && haskey(field, "ffmt") for field in states_fields)

            isotopologue = ExoMol.load_isotopologue(sample_dir)
            @test !isempty(isotopologue.states)
            @test !isempty(isotopologue.transitions)

            state_symbols = [Symbol(field["name"]) for field in states_fields]
            for state in isotopologue.states
                for (field, symbol) in zip(states_fields, state_symbols)
                    @test hasproperty(state, symbol)
                    expected_type = ExoMol._fortran_to_type(field["ffmt"])
                    @test getproperty(state, symbol) isa expected_type
                end
            end

            id_symbol = _state_id_symbol(states_fields)
            if id_symbol !== nothing
                state_ids = getproperty.(isotopologue.states, id_symbol)
                sample_ids = state_ids[1:min(length(state_ids), 10)]
                @test sample_ids == sort(sample_ids)
            end

            energy_symbol = _find_field_symbol(states_fields, ["energy", "e"])
            if energy_symbol !== nothing
                ground_state = first(isotopologue.states)
                energy_value = getproperty(ground_state, energy_symbol)
                if energy_value isa Real
                    @test isapprox(energy_value, 0.0; atol=1e-6)
                end
            end

            for t in isotopologue.transitions
                @test t isa ExoMol.Transition
                @test t.A > 0
                @test t.wavenumber > 0
                if id_symbol !== nothing
                    @test t.upper_id isa Int
                    @test t.lower_id isa Int
                end
            end

            if id_symbol !== nothing
                available_ids = Set(getproperty.(isotopologue.states, id_symbol))
                @test all(t -> t.upper_id in available_ids && t.lower_id in available_ids, isotopologue.transitions)
            end
        end
    end
end
