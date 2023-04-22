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
    slice = TiffImages.load(scan_slice_path(scan, iz); mmap=true)
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

build_grid_layer(scan::HerculaneumScan, jz::Int) = begin
  Base.GC.gc()
  println("GC done.")
  cells = Array{Gray{N0f16}}(undef, (GRID_SIZE, GRID_SIZE, GRID_SIZE, 4, 4))
  println("Cells allocated.")
  cy, cx, cz = grid_size(scan)
  for jy in 1:4:cy
    for jx in 1:4:cx
      by, bx = jy:min(jy+3, cy), jx:min(jx+3, cx)
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
