# Download data for https://scrollprize.org
# It is hosted at http://dl.ash2txt.org

using Downloads, Base64
using Printf, Images, FileIO

# include("data.jl")


download_file_to_out(path, out) = begin
  url = "$DATA_URL/$path"
  auth = base64encode(ENV["VESUVIUS_SERVER_AUTH"])
  Downloads.download(url, out, headers=["Authorization" => "Basic $auth"])
end

"""
    download_file_without_saving(path)

Load a TIFF file from the server into memory without saving it to disk.
"""
download_file_without_saving(path) = begin
  buffer = IOBuffer()
  download_file_to_out(path, buffer)
  bufstream = TiffImages.getstream(format"TIFF", buffer)
  TiffImages.load(read(bufstream, TiffFile))
end

"""
    download_file(path)

Download a file from the data server. It will be saved to `DATA_DIR/path`.
"""
download_file(path) = begin
  out = "$DATA_DIR/$path"
  if !isfile(out)
    download_file_to_out(path, out)
  end
end

"""
    download_scan_slices(scan::HerculaneumScan, slices::AbstractArray{Int}; quiet=false)

Download scan slices from the server into `DATA_DIR`. `slices` specifies which,
and is often a range.
"""
download_scan_slices(scan::HerculaneumScan, slices::AbstractArray{Int}; quiet=false) = begin
  @assert isdir(DATA_DIR) "data directory not found"
  mkpath("$DATA_DIR/$(scan.path)")
  nslices = length(slices)
  for (i, iz) in enumerate(slices)
    filename = scan_slice_filename(scan, iz)
    quiet || println("Downloading $filename ($i/$nslices)...")
    download_file("$(scan.path)/$filename")
  end
end

"""
    download_grid_layer(scan::HerculaneumScan, jz::Int)

Download all scan slices required to build a layer of the grid. Requires
`2*scan.width*scan.height*500` B of disk space (60 GB for scroll 1).
"""
download_grid_layer(scan::HerculaneumScan, jz::Int) = begin
  layers = 1:ceil(Int, scan.slices / GRID_SIZE)
  @assert jz in layers "lz out of bounds"
  download_scan_slices(scan, grid_cell_range(jz, scan.slices))
end

"""
    download_grid_cells_range(scan::HerculaneumScan, jys, jxs, jzs; quiet=false)

Download grid cell files from the data server. Use ranges for `jys`, `jxz` and
`jzs` to specify which. Each grid cell is 238 MB.
"""
download_grid_cells_range(scan::HerculaneumScan, jys, jxs, jzs; quiet=false) = begin
  for jy in jys, jx in jxs, jz in jzs
    quiet || println("Downloading $filename...")
    download_file(grid_cell_server_path(scan, jy, jx, jz))
  end
end

"""
    download_small_slices(scan::HerculaneumScan)

Downloads the slices of a scan from the data server that are required to build
the "small" dataset (one out of `SMALLER_BY` slices). This is still a lot of
data, ballpark about 300GB (120MB * scan.slices). Check that you have enough
free disk space before running. It will also take a long time.

"""
download_small_slices(scan::HerculaneumScan) =
  download_scan_slices(scan, 1:SMALLER_BY:scan.slices)

