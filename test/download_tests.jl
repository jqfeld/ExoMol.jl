using ExoMol
using Test

@testset "master database" begin
  db = get_exomol_master()
  @test db["ID"] == "EXOMOL.master"
  @test haskey(db, "version")
  @test haskey(db, "molecules")
  @test haskey(db, "num_isotopologues")
  @test haskey(db, "num_datasets")
  @test haskey(db, "num_molecules")
  @test length(db["molecules"]) == db["num_molecules"]
end

@testset "save_dataset" begin
  get_exomol_dataset("N2", "14N2", "WCCRMT")
  dest = mktempdir()
  result = save_dataset(dest, "N2", "14N2", "WCCRMT")
  @test result == dest
  saved = readdir(dest)
  @test "14N2__WCCRMT.def.json" in saved
  @test "14N2__WCCRMT.states.bz2" in saved
  @test "14N2__WCCRMT.trans.bz2" in saved
  @test "14N2__WCCRMT.pf" in saved
  # ERJ file has no 'size' key in the API response — must not be silently dropped
  @test "14N2__WCCRMT__ERJ.trans.bz2" in saved

  iso = load_isotopologue(dest)
  @test length(iso.states) == 58380
  @test length(iso.transitions) == 8389500
  @test isempty(iso.broadeners)

  save_dataset(dest, "N2", "14N2", "WCCRMT"; force=false)
  save_dataset(dest, "N2", "14N2", "WCCRMT"; force=true)

  # wn_range on the folder-based loader: WCCRMT's unsegmented main trans file
  # always passes the filter regardless of range. Its supplementary
  # "__ERJ.trans.bz2" file (added later, contains the C-B system — see the
  # "wn_range filtering" testset below) doesn't match any recognized
  # filename pattern either, so it's *also* always included (can't determine
  # its coverage from the name, and the safe default is to include rather
  # than silently drop in-range data) — regardless of range, both files are
  # loaded and the count is the same as loading with no filter at all.
  iso_wn = load_isotopologue(dest; wn_range=(0, 10000))
  @test length(iso_wn.states) == 58380
  @test length(iso_wn.transitions) == 8389500

  # Even a range entirely above the dataset max includes both files, for the
  # same reason: the unsegmented file always passes, and the unrecognized
  # "__ERJ" suffix can't be excluded on name alone.
  iso_all = load_isotopologue(dest; wn_range=(99999, 100000))
  @test length(iso_all.transitions) == 8389500
end

@testset "trans urls include size-less files" begin
  urls = ExoMol._fetch_trans_urls("N2", "14N2", "WCCRMT")
  names = basename.(getfield.(urls, :url))
  @test "14N2__WCCRMT.trans.bz2" in names
  @test "14N2__WCCRMT__ERJ.trans.bz2" in names
  erj = urls[findfirst(u -> basename(u.url) == "14N2__WCCRMT__ERJ.trans.bz2", urls)]
  @test isnothing(erj.size)
end

@testset "wn_range filtering" begin
  f = ExoMol._trans_in_wn_range

  # Unsegmented file always passes
  @test  f("1H2-16O__BT2.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test  f("1H2-16O__BT2.trans.bz2", "1H2-16O", "BT2", (500, 600))

  # File fully inside range
  @test  f("1H2-16O__BT2__00250-00500.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test  f("1H2-16O__BT2__00250-00500.trans.bz2", "1H2-16O", "BT2", (250, 500))

  # Exact boundary: lower == wn_min and upper == wn_max
  @test  f("1H2-16O__BT2__00000-00100.trans.bz2", "1H2-16O", "BT2", (0, 100))

  # File partially overlaps range → included (overlap semantics)
  @test  f("1H2-16O__BT2__00900-01100.trans.bz2", "1H2-16O", "BT2", (0, 1000))
  @test  f("1H2-16O__BT2__00000-00250.trans.bz2", "1H2-16O", "BT2", (100, 1000))
  @test  f("1H2-16O__BT2__00500-01000.trans.bz2", "1H2-16O", "BT2", (0, 900))

  # File entirely outside range → excluded
  @test !f("1H2-16O__BT2__00000-00100.trans.bz2", "1H2-16O", "BT2", (200, 500))
  @test !f("1H2-16O__BT2__00600-01000.trans.bz2", "1H2-16O", "BT2", (100, 500))

  # Unrecognised suffix → included (can't determine its coverage from the
  # name alone, so the safe default is to include it rather than risk
  # silently dropping in-range data — see N2/WCCRMT's real "__ERJ" file,
  # which turned out to hold an entire band system omitted by this filter
  # before this behavior was fixed), and a warning is emitted so the caller
  # knows a heuristic decision was made.
  @test_logs (:warn, r"doesn't match a recognized wavenumber-range naming pattern") begin
    @test f("1H2-16O__BT2__ERJ.trans.bz2", "1H2-16O", "BT2", (0, 99999))
  end
end

@testset "read_broad_file" begin
  path = tempname()
  write(path, "a0 0.07 0.5\na1 0.0916 0.790 0 1\n\n")
  records = read_broad_file(path)
  rm(path)

  @test length(records) == 2
  @test records[1].code    == "a0"
  @test records[1].gamma_L ≈ 0.07
  @test records[1].n_air   ≈ 0.5
  @test isnan(records[1].q1)
  @test isnan(records[1].q2)
  @test records[2].code    == "a1"
  @test records[2].gamma_L ≈ 0.0916
  @test records[2].n_air   ≈ 0.790
  @test records[2].q1      == 0.0
  @test records[2].q2      == 1.0
end
