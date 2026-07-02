#!/usr/bin/env bash
# gmx_pca_commands.sh
# Native GROMACS PCA workflow — plain command sequence, no wrapper logic.
# Edit topol.tpr / traj.xtc below to match your files, then run:
#   chmod +x gmx_pca_commands.sh
#   ./gmx_pca_commands.sh
#
# NOTE: steps 2-6 will pause and prompt you to choose a group interactively
# (e.g. type the number/name for "C-alpha" or "Backbone"). Choose the SAME
# group every time you're prompted.

# Make sure GROMACS is sourced
source /usr/local/gromacs/bin/GMXRC

# 1. Create an index group to work with (pick C-alpha or Backbone when prompted)
gmx_mpi make_ndx -f em.tpr -o index.ndx

# 2. Remove rotation/translation — REQUIRED before PCA
echo 1 0 |gmx_mpi trjconv -s md_0_200.tpr -f md_0_200.xtc -n index.ndx -o traj_fit.xtc -fit rot+trans
# -> prompts for a group: choose your fit group (e.g. C-alpha)

# 3. Build & diagonalize the covariance matrix
echo 3 3 |gmx_mpi covar -s md_0_200.tpr -f traj_fit.xtc -n index.ndx \
    -o eigenvalues.xvg -v eigenvectors.trr -av average.pdb -mwa
# -> prompts twice for a group: choose the SAME group both times (e.g. C-alpha)

# 4. Project trajectory onto PC1 & PC2 (2D scatter)
echo 3 3 |gmx_mpi anaeig -s md_0_200.tpr -f traj_fit.xtc -n index.ndx \
    -v eigenvectors.trr -first 1 -last 2 -2d proj_pc1_pc2.xvg
# -> prompts twice: same group again

# 5. 1D time series of PC1 and PC2 separately (check convergence)
echo 3 3 |gmx_mpi anaeig -s md_0_200.tpr -f traj_fit.xtc -n index.ndx \
    -v eigenvectors.trr -first 1 -last 1 -proj pc1_1d.xvg

echo 3 3 |gmx_mpi anaeig -s md_0_200.tpr -f traj_fit.xtc -n index.ndx \
    -v eigenvectors.trr -first 2 -last 2 -proj pc2_1d.xvg

# 6. Extreme structures for PC1 and PC2 (for visualizing the motion in VMD/PyMOL)
echo 3 3 |gmx_mpi anaeig -s md_0_200.tpr -f traj_fit.xtc -n index.ndx \
    -v eigenvectors.trr -first 1 -last 1 -extr pc1_extreme.pdb -nframes 2

echo 3 3 |gmx_mpi anaeig -s md_0_200.tpr -f traj_fit.xtc -n index.ndx \
    -v eigenvectors.trr -first 2 -last 2 -extr pc2_extreme.pdb -nframes 2

# 7. Per-residue RMSF (complements PCA)
echo 3 3 |gmx_mpi rmsf -s md_0_200.tpr -f traj_fit.xtc -n index.ndx -o rmsf.xvg -res

# 8. (Optional) 2D free-energy landscape on PC1/PC2
gmx_mpi sham -f proj_pc1_pc2.xvg -ls fel_pc1_pc2.xpm -notime

# 9. 2D image generation
gmx_mpi xpm2ps -f fel_pc1_pc2.xpm -o fel_pc1_pc2.eps -rainbow red

# 9. (Optional) View results
xmgrace eigenvalues.xvg
xmgrace proj_pc1_pc2.xvg
vmd pc1_extreme.pdb          # toggle the 2 frames to visualize the PC1 motion
