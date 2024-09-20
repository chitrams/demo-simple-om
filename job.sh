#!/bin/bash

#SBATCH --job-name=OpenMalaria
#SBATCH --time=24:00:00
#SBATCH --account=pawsey0010
#SBATCH --partition=work
#SBATCH --output=log/%a.err #/dev/null
#SBATCH --error=log/%a.out #/dev/null
#SBATCH --mem=10G
#SBATCH --ntasks=@NTASKS@
#SBATCH --cpus-per-task=1

##SBATCH --qos=1day
##SBATCH --array=@START@-@END@%1000

export LMOD_DISABLE_SAME_NAME_AUTOSWAP=no

ml parallel/20220522

ml singularity/4.1.0-slurm
parallel --joblog joblog.txt -j @NTASKS@ < commands.txt

#SEEDFILE="commands.txt"
#SEED=$(sed -n ${SLURM_ARRAY_TASK_ID}p $SEEDFILE)
#eval $SEED
