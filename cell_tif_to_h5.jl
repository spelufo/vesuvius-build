# To run this as a standalone script:
# $ julia
# julia> include("cell_tif_to_h5.tif")
# julia> cell_to_h5(".../cell_yxz_001_001_001.tif", ".../cell.h5")


using Images, TiffImages, HDF5

"""
  Convert a cell tif volume file (e.g. "cell_yxz_001_001_001.tif") to HDF5
  for loading in Ilastik.
"""
cell_to_h5(inputfile::String, outputfile::String) = begin
  V = load(inputfile)
  W = reinterpret.(UInt16, gray.(V))         # -> UInt16[]
  X = permutedims(W, (2, 1, 3))              # yxz -> xyz
  Y = reshape(X, (1, size(X)..., 1))         # ilastik's txyzc coords order
  h5open(outputfile, "w") do f
    f["data", chunk=(1, 64, 64, 64, 1)] = Y  # ilastik wants chunked hdf5
  end
  nothing
end

