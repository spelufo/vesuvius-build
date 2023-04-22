# Download data for https://scrollprize.org
# It is hosted at http://dl.ash2txt.org

using Downloads
using Printf, Images, FileIO

# include("data.jl")


download_file_to_out(path, out) = begin
  url = "$DATA_URL/$path"
  auth = ENV["VESUVIUS_SERVER_AUTH"]
  Downloads.download(url, out, headers=["Authorization" => "Basic $auth"])
end

download_file_without_saving(path) = begin
  buffer = IOBuffer()
  download_file_to_out(path, buffer)
  bufstream = TiffImages.getstream(format"TIFF", buffer)
  TiffImages.load(read(bufstream, TiffFile))
end


download_file(path) = begin
  out = "$DATA_DIR/$path"
  if !isfile(out)
    dowload_file_to_out(path, out)
  end
end

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

download_grid_layer(scan::HerculaneumScan, jz::Int) = begin
  layers = 1:ceil(Int, scan.slices / GRID_SIZE)
  @assert jz in layers "lz out of bounds"
  download_scan_slices(scan, grid_cell_range(jz, scan.slices))
end

# Needs lots of disk space, ballpark about 300GB. It will also take a long time.
# Use download_scan_slices(scan, iy0:SMALLER_BY:iy1) instead if needed.
download_small_slices(scan::HerculaneumScan) =
  download_scan_slices(scan, 1:SMALLER_BY:scan.slices)

