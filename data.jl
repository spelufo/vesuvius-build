using LinearAlgebra, StaticArrays, GeometryBasics, Quaternions
using Images, TiffImages


# Source data ##################################################################

const DATA_URL = "http://dl.ash2txt.org"
const DATA_DIR = "$(dirname(@__DIR__))/data"

struct HerculaneumScan
  path :: String
  resolution_um :: Float32
  xray_energy_KeV :: Float32
  width::Int
  height::Int
  slices::Int
end

const scroll_1_54 = HerculaneumScan("full-scrolls/Scroll1.volpkg/volumes/20230205180739", 7.91f0, 54f0, 8096, 7888, 14376)
const scroll_2_54 = HerculaneumScan("full-scrolls/Scroll2.volpkg/volumes/20230210143520", 7.91f0, 54f0, 11984, 10112, 14428)
const scroll_2_88 = HerculaneumScan("full-scrolls/Scroll2.volpkg/volumes/20230212125146", 7.91f0, 88f0, 11136, 8480, 1610)

const pherc_0332_53 = HerculaneumScan("full-scrolls/PHerc0332.volpkg/volumes/20231027191953", 3.24f0, 53f0, 9414, 9414, 22941)
const pherc_1667_88 = HerculaneumScan("full-scrolls/PHerc1667.volpkg/volumes/20231107190228", 3.24f0, 88f0, 8120, 7960, 26391)
const pherc_0332_53_791 = HerculaneumScan("full-scrolls/PHerc0332.volpkg/volumes/20231117143551", 7.91f0, 53f0, 3400, 3550, 9778)
const pherc_1667_88_791 = HerculaneumScan("full-scrolls/PHerc1667.volpkg/volumes/20231117161658", 7.91f0, 53f0, 3440, 3340, 11174)

const fragment_1_54 = HerculaneumScan("fragments/Frag1.volpkg/volumes/20230205142449", 3.24f0, 54f0, 7198, 1399, 7219)
const fragment_1_88 = HerculaneumScan("fragments/Frag1.volpkg/volumes/20230213100222", 3.24f0, 88f0, 7332, 1608, 7229)
const fragment_2_54 = HerculaneumScan("fragments/Frag2.volpkg/volumes/20230216174557", 3.24f0, 54f0, 9984, 2288, 14111)
const fragment_2_88 = HerculaneumScan("fragments/Frag2.volpkg/volumes/20230226143835", 3.24f0, 88f0, 10035, 2112, 14144)
const fragment_3_54 = HerculaneumScan("fragments/Frag3.volpkg/volumes/20230215142309", 3.24f0, 54f0, 6312, 1440, 6656)
const fragment_3_88 = HerculaneumScan("fragments/Frag3.volpkg/volumes/20230212182547", 3.24f0, 88f0, 6108, 1644, 6650)

@inline zpad(i::Int, ndigits::Int)::String =
  lpad(i, ndigits, "0")

@inline scan_slice_filename(scan::HerculaneumScan, iz::Int)::String = begin
  ndigits = ceil(Int, log10(scan.slices))
  zpad((iz - 1), ndigits) * ".tif"
end

@inline scan_slice_server_path(scan::HerculaneumScan, iz::Int)::String =
  "$(scan.path)/$(scan_slice_filename(scan, iz))"

@inline scan_slice_path(scan::HerculaneumScan, iz::Int)::String =
  "$DATA_DIR/$(scan_slice_server_path(scan, iz))"

@inline scan_slice_url(scan::HerculaneumScan, iz::Int)::String =
  "$DATA_URL/$(scan_slice_server_path(scan, iz))"

@inline scan_dimensions_mm(scan::HerculaneumScan) =
  scan.resolution_um * Vec3f(scan.width, scan.height, scan.slices) / 1000f0

@inline scan_position_mm(scan::HerculaneumScan, iy::Int, ix::Int, iz::Int) =
  scan.resolution_um * Vec3f(ix-1, iy-1, iz-1) / 1000f0

# Grid #########################################################################

const GRID_DIR = DATA_DIR
const GRID_SIZE = 500  # The size of each cell.

# The size of the grid, in number of cells.
@inline grid_size(scan::HerculaneumScan) =
  ( ceil(Int, scan.height / GRID_SIZE),
    ceil(Int, scan.width / GRID_SIZE),
    ceil(Int, scan.slices / GRID_SIZE) )

@inline grid_size(scan::HerculaneumScan, dim::Int) =
  grid_size(scan)[dim]

@inline grid_cell_range(j::Int, max::Int) =
  GRID_SIZE*(j - 1) + 1 : min(GRID_SIZE*j, max)

@inline grid_cell_filename(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int)::String =
  "cell_yxz_$(zpad(jy, 3))_$(zpad(jx, 3))_$(zpad(jz, 3)).tif"

@inline grid_cell_server_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int)::String = begin
  path = replace(scan.path, "/volumes/" => "/volume_grids/")
  "$path/$(grid_cell_filename(scan, jy, jx, jz))"
end

@inline grid_cell_path(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int)::String =
  "$GRID_DIR/$(grid_cell_server_path(scan, jy, jx, jz))"

have_grid_cell(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  isfile(grid_cell_path(scan, jy, jx, jz))

have_grid_cells(scan::HerculaneumScan, jys::UnitRange{Int}, jxs::UnitRange{Int}, jz::Int) = begin
  for jy in jys, jx in jxs
    have_grid_cell(scan, jy, jx, jz) || return false
  end
  true
end

load_grid_cell(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) =
  load(grid_cell_path(scan, jy, jx, jz))


# Small ########################################################################

const SMALL_DIR = "$(dirname(@__DIR__))/data_small"
const SMALLER_BY = 10

@inline small_size(scan::HerculaneumScan) =
  ( length(1:SMALLER_BY:scan.height),
    length(1:SMALLER_BY:scan.width),
    length(1:SMALLER_BY:scan.slices) )

@inline small_slice_path(scan::HerculaneumScan, iz::Int)::String =
  "$SMALL_DIR/$(scan.path)/$(scan_slice_filename(scan, iz))"

@inline small_volume_path(scan::HerculaneumScan)::String =
  "$SMALL_DIR/$(scan.path)_small.tif"


load_small_volume(scan::HerculaneumScan; mmap=true) =
  TiffImages.load(small_volume_path(scan); mmap=mmap)
