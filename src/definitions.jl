using JSON


function read_def_file(filename;)
  if endswith(filename, ".json")
    return JSON.parsefile(filename)
  end

  error("Original ExoMol format not supported yet. Please use JSON format instead.")

  # open(filename, "r") do f
  #   if !startswith(readline(f), "EXOMOL.def")
  #     error("Not a ExoMol definitions file")
  #   end
  #
  #   def = Dict(
  #     "dataset" => Dict(),
  #     "atoms" => Dict(),
  #     "isotopologue" => Dict(),
  #     "partition_function" => Dict(),
  #     "broad" => Dict(),
  #     "irreducible_representations" => Dict(),
  #   )
  #
  #
  #   def["isotopologue"]["iso_formula"] = split(readline(f))[1]
  #   def["isotopologue"]["iso_slug"] = split(readline(f))[1]
  #   def["dataset"]["name"] = split(readline(f))[1]
  #   def["dataset"]["version"] = split(readline(f))[1]
  #   def["isotopologue"]["inchi"] = split(readline(f))[1]
  #   def["atoms"]["number_of_atoms"] = parse(Int, split(readline(f))[1])
  #   def["atoms"]["element"] = Dict()
  #   for i in 1:def["atoms"]["number_of_atoms"]
  #
  #   end
    # return def
  # end
  
end
