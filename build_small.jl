using Images, TiffImages

include("data.jl")
include("downloader.jl")


save_small_slice(scan::HerculaneumScan, slice, iz::Int) = begin
  ly, lx = size(slice)
  iys = 1:SMALLER_BY:ly
  ixs = 1:SMALLER_BY:lx
  small_slice = zeros(Gray{N0f16}, (length(iys), length(ixs)))
  for (iiy ,iy) in enumerate(iys)
    for (iix, ix) in enumerate(ixs)
      small_slice[iiy, iix] = slice[iy, ix]
    end
  end
  save(small_slice_path(scan, iz), small_slice)
  nothing
end

build_small_slice_from_disk(scan::HerculaneumScan, iz::Int) = begin
  if isfile(small_slice_path(scan, iz)) return end
  slice = TiffImages.load(scan_slice_path(scan, iz); mmap=true)
  save_small_slice(scan, slice, iz)
end

build_small_slice_from_server(scan::HerculaneumScan, iz::Int) = begin
  if isfile(small_slice_path(scan, iz)) return end
  slice = download_file_without_saving(scan_slice_server_path(scan, iz))
  save_small_slice(scan, slice, iz)
end

build_small_range(scan::HerculaneumScan, izbounds::UnitRange{Int}; from=:disk) = begin
  mkpath(dirname(small_slice_path(scan, 1)))
  izs = intersect(1:SMALLER_BY:scan.slices, izbounds)
  for (i, iz) in enumerate(izs)
    if i % 10 == 0
      println("Building small ($i/$(length(izs)))")
      # Base.GC.gc() # Did this on scroll 1. Probably a bad idea, faster not to.
    end
    if from == :disk
      build_small_slice_from_disk(scan, iz)
    else
      build_small_slice_from_server(scan, iz)
    end
  end
end

build_small_layer(scan::HerculaneumScan, jz::Int; from=:disk) =
  build_small_range(scan, grid_cell_range(jz, scan.slices), from=from)

"""
    build_small(scan::HerculaneumScan; from=:server)

Builds the downsampled slice files for the "small" dataset. The `from` argument
can be `:server` or `:disk`. Building from disk uses the full resolution slices
on your DATA_DIR. Building from the server loads them from the server into
memory, so as not to require as much disk space.
"""
build_small(scan::HerculaneumScan; from=:server) =
  build_small_range(scan, 1:scan.slices, from=from)

"""
    build_small_volume(scan::HerculaneumScan)

Builds the `<SCAN>_small.tif` 3D tif file containing the "small" dataset: A low
resolution version of the scroll saved as a 3D tif file.

You must first run `build_small` to build the files this uses as input.
"""
build_small_volume(scan::HerculaneumScan) = begin
  vol = Array{Gray{N0f16}}(undef, small_size(scan))
  for (i, iz) in enumerate(1:SMALLER_BY:scan.slices)
    vol[:,:, i] = TiffImages.load(small_slice_path(scan, iz); mmap=true)
  end
  save(small_volume_path(scan), vol)
end
