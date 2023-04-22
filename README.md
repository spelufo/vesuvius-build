# vesuvius-build

Scripts to build files for progressive loading of the data from the
[vesuvius challenge](https://scrollprize.org). They produce 3d tiff files.


## The coordinate system

* y axis: Top down when viewing one of the slice tif images.
* x axis: Left to right when viewing one of the slice tif images.
* z axis: Low number to high number on the tif image slice filenames.

Once loaded into julia it is indexed as `vol[iy, ix, iz]`.


## The grid

Splits the scanned volume into cells of 500x500x500 voxels. A file is produced
for each one `cell_yxz_YYY_XXX_ZZZ.tif`.
