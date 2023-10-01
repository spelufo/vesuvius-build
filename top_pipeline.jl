const CELLS_DIR = "../data/full-scrolls/Scroll1.volpkg/volume_grids/20230205180739"
const SEGDATA_DIR = "../data/segmentation"

include("cell_tif_to_h5.jl")
include("ilastik_objids_to_meshes.jl")

@inline zpad(i::Int, ndigits::Int)::String =
  lpad(i, ndigits, "0")

cell_filename(cell_jy::Int, cell_jx::Int, cell_jz::Int) =
  "cell_yxz_$(zpad(cell_jy, 3))_$(zpad(cell_jx, 3))_$(zpad(cell_jz, 3))"


top_pipeline(cell_jy::Int, cell_jx::Int, cell_jz::Int) = begin
  # 0. Setup.
  cell_name = cell_filename(cell_jy, cell_jx, cell_jz)
  cell_dir = "$SEGDATA_DIR/$cell_name"
  isdir(cell_dir) || mkdir(cell_dir)

  # 1. Download from volume_grids.   `*.tif`                  ( 250M)
  raw_tif_file = "$CELLS_DIR/$cell_name.tif"
  if !isfile(raw_tif_file)
    println("File not found: $raw_tif_file")
    println("You may need to download it from the server")
    println("or symlink ../data to a local directory that mirrors the server's files.")
    return
  end

  # 2. Convert to h5 for ilastik.    `*.h5`                   ( 250M) (  20s)
  raw_h5_file = "$cell_dir/$cell_name.h5"
  @time if !isfile(raw_h5_file)
    println("Converting tif to h5...")
    cell_to_h5(raw_tif_file, raw_h5_file)
  end

  # 3. Ilastik pixel classification. `*_probabilities.h5`     (1000M) ( 180s)
  probabilities_file = "$cell_dir/$(cell_name)_probabilities.h5"
  @time if !isfile(probabilities_file)
    println("Running ilastik pixel classification...")
    run(pipeline(
      `/opt/ilastik/run_ilastik.sh --project ./ilastik/Vesuvius.ilp
      --headless --readonly
      --export_source Probabilities
      --output_filename_format $probabilities_file
      $cell_dir/$cell_name.h5`,
      stdout="/tmp/ilastik_pixel_classification.log",
      stderr="/tmp/ilastik_pixel_classification.log"))
    # TODO: Maybe try configuring the project with less features and see if it
    # works just as well, so that it is faster. After having the whole pipeline.
  end

  # 4. Ilastik segmentation.         `*_hole_ids.h5`          ( 500M) (  28s)
  hole_ids_file = "$cell_dir/$(cell_name)_hole_ids.h5"
  @time if !isfile(hole_ids_file)
    println("Running ilastik segmentation...")
    run(pipeline(
      `/opt/ilastik/run_ilastik.sh --project ./ilastik/Vesuvius_seg3.ilp
      --headless --readonly
      --export_source 'Object Identities'
      --output_filename_format $hole_ids_file
      --raw_data $cell_dir/$cell_name.h5
      --prediction_maps $cell_dir/$(cell_name)_probabilities.h5`,
      stdout="/tmp/ilastik_segmentation.log",
      stderr="/tmp/ilastik_segmentation.log"))
  end


  # 5. Marching cubes.               `holes/*.stl`             ( 750M) ( 35s)
  hole_dir = "$cell_dir/holes"
  @time if !isdir(hole_dir)
    println("Building hole meshes...")
    mkdir(hole_dir)
    hole_ids_to_meshes(hole_ids_file, "$hole_dir/$(cell_name)_hole_", cell_jy, cell_jx, cell_jz)
  end

  # 6. Cleanup intermediate files.
  # rm(raw_h5_file)
  # rm(probabilities_file)
  # rm(hole_ids_file)

  nothing
end
