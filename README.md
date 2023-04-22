# vesuvius-build

Scripts to build files for progressive loading of the data from the
[vesuvius challenge](https://scrollprize.org). They produce 3d tiff files.

How long the scripts run and how much space they need depends on how much data
you ask them to process. There are no safeguards. Use at your own risk.

## The coordinate system

* y axis: Top down when viewing one of the slice tif images.
* x axis: Left to right when viewing one of the slice tif images.
* z axis: Low number to high number on the tif image slice filenames.

Once loaded into julia it is indexed as `vol[iy, ix, iz]`.


## The grid

Splits the scanned volume into cells of 500x500x500 voxels. A file is produced
for each one `cell_yxz_YYY_XXX_ZZZ.tif`.

## The "small"

A 1/10 in each dimension version of the data.

After this are built, out of these

## Directory structure

```
./data
  The data from the server, downloaded following the same directory structure
  used in the server. Only source data here.

./data_grid
  The grid files produced by `build_grid.jl`. Mirrors the directory structure
  on the server, but instead of the slices there are cell files.

./data_small
  The "small" version of the data produced by `build_small.jl`. Mirror the dir
  structure on the server, but only has 1 in ten slices, downsampled. Also has
  the $voldir_small.tif file, a 3d tiff file with the whole scan at this
  resolution (~1.7GB for scroll 1).
```

## Running

I haven't done almost any work to make this easy to use by others. Be prepared
to delve into the code if needed to debug issues that arise.

Need julia installed, and the packages used (`]add Images, TiffImages, FileIO`, etc.).

Set the `VESUVIUS_SERVER_AUTH` environment variable to the server's `user:password`. Only needed if downloading slices.

An example run, building layer 2 of the grid.

```
julia> include("build_grid.jl");
julia> build_grid_layer(scroll_1_54, 2)
GC done.
Cells allocated.
Building grid cells (1:1, 1:16)...
Building grid cells (1:1, 17:17)...
Building grid cells (2:2, 1:16)...
Building grid cells (2:2, 17:17)...
Building grid cells (3:3, 1:16)...
Building grid cells (3:3, 17:17)...
Building grid cells (4:4, 1:16)...
Building grid cells (4:4, 17:17)...
Building grid cells (5:5, 1:16)...
Building grid cells (5:5, 17:17)...
Building grid cells (6:6, 1:16)...
Building grid cells (6:6, 17:17)...
Building grid cells (7:7, 1:16)...
Building grid cells (7:7, 17:17)...
Building grid cells (8:8, 1:16)...
Building grid cells (8:8, 17:17)...
Building grid cells (9:9, 1:16)...
Building grid cells (9:9, 17:17)...
Building grid cells (10:10, 1:16)...
Building grid cells (10:10, 17:17)...
Building grid cells (11:11, 1:16)...
Building grid cells (11:11, 17:17)...
Building grid cells (12:12, 1:16)...
Building grid cells (12:12, 17:17)...
Building grid cells (13:13, 1:16)...
Building grid cells (13:13, 17:17)...
Building grid cells (14:14, 1:16)...
Building grid cells (14:14, 17:17)...
Building grid cells (15:15, 1:16)...
Building grid cells (15:15, 17:17)...
Building grid cells (16:16, 1:16)...
Building grid cells (16:16, 17:17)...
6603.302321 seconds (37.16 M allocations: 5.547 GiB, 35.31% gc time, 0.05% compilation time: 32% of which was recompilation)
```

Building the small version is done in two stages: first produce a downsampled
version of every tenth slice from the server. Then build the `*_small.tiff`
volume file out of those.

```julia
julia> include("build_small.jl")
julia> @time build_small(scroll_1_54)
Building small (10/1438)
Building small (20/1438)
Building small (30/1438)
Building small (40/1438)
Building small (50/1438)
Building small (60/1438)
Building small (70/1438)
Building small (80/1438)
Building small (90/1438)
Building small (100/1438)
Building small (110/1438)
Building small (120/1438)
Building small (130/1438)
Building small (140/1438)
Building small (150/1438)
Building small (160/1438)
Building small (170/1438)
Building small (180/1438)
Building small (190/1438)
Building small (200/1438)
Building small (210/1438)
Building small (220/1438)
Building small (230/1438)
Building small (240/1438)
Building small (250/1438)
Building small (260/1438)
Building small (270/1438)
Building small (280/1438)
Building small (290/1438)
Building small (300/1438)
Building small (310/1438)
Building small (320/1438)
Building small (330/1438)
Building small (340/1438)
Building small (350/1438)
Building small (360/1438)
Building small (370/1438)
Building small (380/1438)
Building small (390/1438)
Building small (400/1438)
Building small (410/1438)
Building small (420/1438)
Building small (430/1438)
Building small (440/1438)
Building small (450/1438)
Building small (460/1438)
Building small (470/1438)
Building small (480/1438)
Building small (490/1438)
Building small (500/1438)
Building small (510/1438)
Building small (520/1438)
Building small (530/1438)
Building small (540/1438)
Building small (550/1438)
Building small (560/1438)
Building small (570/1438)
Building small (580/1438)
Building small (590/1438)
Building small (600/1438)
Building small (610/1438)
Building small (620/1438)
Building small (630/1438)
Building small (640/1438)
Building small (650/1438)
Building small (660/1438)
Building small (670/1438)
Building small (680/1438)
Building small (690/1438)
Building small (700/1438)
Building small (710/1438)
Building small (720/1438)
Building small (730/1438)
Building small (740/1438)
Building small (750/1438)
Building small (760/1438)
Building small (770/1438)
Building small (780/1438)
Building small (790/1438)
Building small (800/1438)
Building small (810/1438)
Building small (820/1438)
Building small (830/1438)
Building small (840/1438)
Building small (850/1438)
Building small (860/1438)
Building small (870/1438)
Building small (880/1438)
Building small (890/1438)
Building small (900/1438)
Building small (910/1438)
Building small (920/1438)
Building small (930/1438)
Building small (940/1438)
Building small (950/1438)
Building small (960/1438)
Building small (970/1438)
Building small (980/1438)
Building small (990/1438)
Building small (1000/1438)
Building small (1010/1438)
Building small (1020/1438)
Building small (1030/1438)
Building small (1040/1438)
Building small (1050/1438)
Building small (1060/1438)
Building small (1070/1438)
Building small (1080/1438)
Building small (1090/1438)
Building small (1100/1438)
Building small (1110/1438)
Building small (1120/1438)
Building small (1130/1438)
Building small (1140/1438)
Building small (1150/1438)
Building small (1160/1438)
Building small (1170/1438)
Building small (1180/1438)
Building small (1190/1438)
Building small (1200/1438)
Building small (1210/1438)
Building small (1220/1438)
Building small (1230/1438)
Building small (1240/1438)
Building small (1250/1438)
Building small (1260/1438)
Building small (1270/1438)
Building small (1280/1438)
Building small (1290/1438)
Building small (1300/1438)
Building small (1310/1438)
Building small (1320/1438)
Building small (1330/1438)
Building small (1340/1438)
Building small (1350/1438)
Building small (1360/1438)
Building small (1370/1438)
Building small (1380/1438)
Building small (1390/1438)
Building small (1400/1438)
Building small (1410/1438)
Building small (1420/1438)
Building small (1430/1438)
236.016895 seconds (5.05 M allocations: 14.266 GiB, 2.62% gc time, 0.01% compilation time)

julia> @time build_small_volume(scroll_1_54)
272.425260 seconds (2.34 M allocations: 1.822 GiB, 89.01% gc time, 0.26% compilation time)
```
