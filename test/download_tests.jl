using ExoMol
using Test

db = get_exomol_master()
@test db["ID"] == "EXOMOL.master"
@test haskey(db, "version")
@test haskey(db, "molecules")
@test haskey(db, "num_species")
@test haskey(db, "num_datasets")
@test haskey(db, "num_molecules")
@test length(db["molecules"]) == db["num_molecules"]
