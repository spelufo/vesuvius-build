using Images, TiffImages

include("data.jl")
include("downloader.jl")


save_grid_cell(scan::HerculaneumScan, cell::AbstractArray{Gray{N0f16},3}, jy::Int, jx::Int, jz::Int) = begin
  path = grid_cell_path(scan, jy, jx, jz)
  mkpath(dirname(path))
  save(path, cell)
end

save_grid_cells(scan::HerculaneumScan, cells::AbstractArray{Gray{N0f16},5}, jys::UnitRange{Int}, jxs::UnitRange{Int}, jz::Int) = begin
  for jy in jys, jx in jxs
    cell = @view cells[:, :, :, jy - jys.start + 1, jx - jxs.start + 1]
    save_grid_cell(scan, cell, jy, jx, jz)
  end
end

load_grid_cell_from_slices(scan::HerculaneumScan, jy::Int, jx::Int, jz::Int) = begin
  cell = zeros(Gray{N0f16}, (GRID_SIZE, GRID_SIZE, GRID_SIZE))
  izs = grid_cell_range(jz, scan.slices)
  iys = grid_cell_range(jy, scan.height)
  ixs = grid_cell_range(jx, scan.width)
  for (cell_iz, iz) in enumerate(izs)
    slice = TiffImages.load(scan_slice_path(scan, iz); mmap=true)
    cell[1:length(iys), 1:length(ixs), cell_iz] = @view slice[iys, ixs]
  end
  cell
end

load_grid_cells_from_slices!(cells::Array{Gray{N0f16}, 5}, scan::HerculaneumScan, jys::UnitRange{Int}, jxs::UnitRange{Int}, jz::Int) = begin
  izs = grid_cell_range(jz, scan.slices)
  black = Gray{N0f16}(0)
  for (cell_iz, iz) in enumerate(izs)
    slice_path = scan_slice_path(scan, iz)
    println("iz: $iz")
    slice = TiffImages.load(slice_path; mmap=true)
    for jy in jys, jx in jxs
      iys = grid_cell_range(jy, scan.height)
      ixs = grid_cell_range(jx, scan.width)
      cells[1:length(iys), 1:length(ixs), cell_iz, jy - jys.start + 1, jx - jxs.start + 1] = @view slice[iys, ixs]
      cells[length(iys)+1:end, 1:length(ixs), cell_iz, jy - jys.start + 1, jx - jxs.start + 1] .= black
      cells[:, length(ixs)+1:end, cell_iz, jy - jys.start + 1, jx - jxs.start + 1] .= black
    end
  end
  nothing
end

"""
    build_grid_layer(scan::HerculaneumScan, jz::Int)

Build a layer of the grid. Requires all slices from that layer on your DATA_DIR.
This takes a long time and requires a lot of memory and disk space.
"""
build_grid_layer(scan::HerculaneumScan, jz::Int) = begin
  Base.GC.gc()
  println("GC done.")
  sy, sx = 4, 4
  cells = Array{Gray{N0f16}}(undef, (GRID_SIZE, GRID_SIZE, GRID_SIZE, sy, sx))
  println("Cells allocated.")
  cy, cx, cz = grid_size(scan)
  for jy in 1:sy:cy
    for jx in 1:sx:cx
      by, bx = jy:min(jy+sy-1, cy), jx:min(jx+sx-1, cx)
      if have_grid_cells(scan, by, bx, jz)
        println("skipping built cells: ($by, $bx)")
      else
        println("Building grid cells ($by, $bx)...")
        load_grid_cells_from_slices!(cells, scan, by, bx, jz)
        save_grid_cells(scan, cells, by, bx, jz)
      end
    end
  end
  nothing
end

"""
    build_grid(scan::HerculaneumScan)

Builds all the grid files for a scroll. Don't run this, use `build_grid_layer`
to build only the layers you need, or better yet, download the grid cell files
from the data server.

This takes a long time and requires a lot of memory and disk space (~4TB/scroll).
We did this on the data server so you don't have to. It took about a day to run.

If you are sure that you still want to run it, comment out the @assert. Also,
you might want to tune the `sx` and `sy` variables in `build_grid_layer` to use
as much RAM as you can spend on the job, which will speed it up.
"""
build_grid(scan::HerculaneumScan) = begin
  @assert false "See ?build_grid. Are you sure you want to run this?"
  _, _, jzs = grid_size(scroll_1_54)
  for jz in 1:jzs
    build_grid_layer(scroll_1_54, jz)
    println("Layer $jz done")
  end
end
