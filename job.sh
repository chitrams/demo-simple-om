#!/bin/bash

#SBATCH --job-name=OpenMalaria
#SBATCH --time=24:00:00
#SBATCH --account=penny
#SBATCH --partition=scicore
#SBATCH --qos=1day
#SBATCH --output=log/%a.err #/dev/null
#SBATCH --error=log/%a.out #/dev/null
#SBATCH --mem=50000MB
#SBATCH --ntasks=@NTASKS@
#SBATCH --cpus-per-task=1

##SBATCH --array=@START@-@END@%1000

export LMOD_DISABLE_SAME_NAME_AUTOSWAP=no

ml OpenMalaria/45.0-intel-compilers-2023.1.0
ml parallel

parallel --progress --joblog joblog.txt -j @NTASKS@ < commands.txt

#SEEDFILE="commands.txt"
#SEED=$(sed -n ${SLURM_ARRAY_TASK_ID}p $SEEDFILE)
#eval $SEED
