#!/bin/bash

PORT=8787
USERNAME=chitrams
ACCOUNT=pawsey0010
REMOTE_DIR=/scratch/pawsey1104/$USERNAME
REMOTE_SCRIPT=rstudio.sh
REMOTE_SCRIPT_PATH=$REMOTE_DIR/$REMOTE_SCRIPT

MAX_DURATION=02:00:00
PARTITION=work
JOB_NAME=rstudio_server
MEMORY=10G

LOCAL_SCRIPT_PATH="/tmp/rstudio.sh"

# Content of the remote RStudio script
cat << 'EOF' > $LOCAL_SCRIPT_PATH
#!/bin/bash -l
# Allocate slurm resources, edit as necessary
#SBATCH --account=$ACCOUNT
#SBATCH --ntasks=1
#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=$MEMORY
#SBATCH --time=$MAX_DURATION
#SBATCH --job-name=$JOB_NAME
#SBATCH --partition=$PARTITION
#SBATCH --export=NONE
#SBATCH --output=$REMOTE_DIR/slurm-%j.out
 
# Set our working directory
# Should be in a writable path with some space, like /scratch
# You'll need to manually change dir to this one through the RStudio interface
# Session -> Set Working Directory -> Choose Directory -> ...
dir="${MYSCRATCH}/rstudio-dir"
 
# Set the image and tag we want to use
image="docker://rocker/tidyverse:4.3.1"
 
# Load Singularity. The version may change over time.
module load singularity/4.1.0-slurm
 
# You should not need to edit the lines below
 
# Prepare the working directory
mkdir -p $dir
cd ${dir}
 
# Get the image filename
imagename=${image##*/}
imagename=${imagename/:/_}.sif
 
# Create a user-specific tmp directory to avoid clashes between users
tmp_dir="/tmp/tmp_$USER"
mkdir -p $tmp_dir
 
# Get the hostname of the Setonix node
# We'll set up an SSH tunnel to connect to the RStudio server
host=$(hostname)
 
# Set the port for the SSH tunnel
# This part of the script uses a loop to search for available ports on the node;
# this will allow multiple instances of GUI servers to be run from the same host node
port=$PORT
pfound="0"
while [ $port -lt 65535 ] ; do
  check=$( ss -tuna | awk '{print $4}' | grep ":$port *" )
  if [ "$check" == "" ] ; then
    pfound="1"
    break
  fi
  : $((++port))
done
if [ $pfound -eq 0 ] ; then
  echo "No available communication port found to establish the SSH tunnel."
  echo "Try again later. Exiting."
  exit
fi
 
# Generate a random password for the session
export PASSWORD=$(openssl rand -base64 15)
 
# Pull our Docker image in a folder
singularity pull $imagename $image
 
echo "*****************************************************"
echo "Setup - from your laptop do:"
echo "ssh -N -f -L ${port}:${host}:${port} $USER@setonix.pawsey.org.au"
echo "*****"
echo "The launch directory is: $dir"
echo "*****"
echo "Secret for this session is: $PASSWORD"
echo "*****************************************************"
echo ""
 
# Launch our container
# Note that content of /home will be lost after runtime
# You'll need to manually change dir to the working dir through the RStudio interface
# Session -> Set Working Directory -> Choose Directory -> ...
srun -N $SLURM_JOB_NUM_NODES -n $SLURM_NTASKS -c $SLURM_CPUS_PER_TASK \
  singularity exec -c \
  -B ${tmp_dir}:/tmp \
  -B ${dir}:$HOME \
  -B ${tmp_dir}:/var \
  ${imagename} \
  rserver --www-port ${port} --www-address 0.0.0.0 --auth-none=0 --auth-pam-helper-path=pam-helper --server-user=$(whoami)
EOF

# Function to kill any process using port $PORT
kill_port_process() {
    PID=$(lsof -t -i:$PORT)
    if [ ! -z "$PID" ]; then
        echo "Port $PORT is already in use by process $PID. Terminating process..."
        kill -9 $PID
        echo "Process $PID terminated."
    else
        echo "Port $PORT is free."
    fi
}

# Function to check job status
check_job_status() {
    JOB_STATUS=$(ssh $USERNAME@setonix.pawsey.org.au "squeue -j $1 -h -o %T")
    echo "$JOB_STATUS"
}

# 1. Kill any process using port $PORT
kill_port_process

sed -i '' "s#\\\$PORT#$PORT#g" $LOCAL_SCRIPT_PATH
sed -i '' "s#\\\$USERNAME#$USERNAME#g" $LOCAL_SCRIPT_PATH
sed -i '' "s#\\\$ACCOUNT#$ACCOUNT#g" $LOCAL_SCRIPT_PATH
sed -i '' "s#\\\$REMOTE_DIR#$REMOTE_DIR#g" $LOCAL_SCRIPT_PATH
sed -i '' "s#\\\$MAX_DURATION#$MAX_DURATION#g" $LOCAL_SCRIPT_PATH
sed -i '' "s#\\\$PARTITION#$PARTITION#g" $LOCAL_SCRIPT_PATH
sed -i '' "s#\\\$JOB_NAME#$JOB_NAME#g" $LOCAL_SCRIPT_PATH
sed -i '' "s#\\\$MEMORY#$MEMORY#g" $LOCAL_SCRIPT_PATH

# 1. Create or replace the remote script, set permissions, and submit the job
echo "Copying the script to the remote cluster..."
scp $LOCAL_SCRIPT_PATH $USERNAME@data-mover.pawsey.org.au:$REMOTE_SCRIPT_PATH

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create the script, set permissions, or submit the sbatch job. Please check the script and try again."
    exit 1
fi

# 2. Submit the sbatch job
SBATCH_OUTPUT=$(ssh $USERNAME@setonix.pawsey.org.au "sbatch $REMOTE_SCRIPT_PATH")

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to submit the sbatch job. Please check the sbatch script path and try again."
    exit 1
fi

# 3. Extract the Job ID from the sbatch output
JOB_ID=$(echo "$SBATCH_OUTPUT" | awk '/Submitted batch job/ {print $4}')

echo "Submitted job with ID: $JOB_ID"

# 4. Wait for the job to start, check its status, and handle failures
while true; do
    JOB_STATUS=$(check_job_status $JOB_ID)
    
    if [ "$JOB_STATUS" == "RUNNING" ]; then
        echo "Job is running. Checking for the secret..."
        break
    elif [ "$JOB_STATUS" == "FAILED" ] || [ "$JOB_STATUS" == "CANCELLED" ] || [ "$JOB_STATUS" == "TIMEOUT" ]; then
        echo "Job failed with status $JOB_STATUS. Here is the content of the Slurm output:"
        ssh $USERNAME@setonix.pawsey.org.au "cat $REMOTE_DIR/slurm-$JOB_ID.out"
        exit 1
    else
        echo "Job status: $JOB_STATUS. Waiting for it to start..."
        sleep 5
    fi
done

# 5. Extract the secret from the Slurm output
while true; do
    SSH_OUTPUT=$(ssh $USERNAME@setonix.pawsey.org.au "grep -i 'Secret for this session' $REMOTE_DIR/slurm-$JOB_ID.out")
    SECRET=$(echo "$SSH_OUTPUT" | awk '{print $NF}')

    if [ ! -z "$SECRET" ]; then
        echo "Secret obtained. Setting up SSH tunnel..."
        break
    else
        echo "Waiting for secret to be available..."
        sleep 5
    fi
done

# 6. Extract the NID (node identifier) from the Slurm output
NID=$(ssh $USERNAME@setonix.pawsey.org.au "grep -oP 'nid[0-9]+' $REMOTE_DIR/slurm-$JOB_ID.out | head -n 1")

# 7. Set up the SSH tunnel using port $PORT
echo "ssh -N -f -L $PORT:$NID:$PORT $USERNAME@setonix.pawsey.org.au"
ssh -N -f -L $PORT:$NID:$PORT $USERNAME@setonix.pawsey.org.au

echo "SSH tunnel established. Secret for this session: $SECRET"

# 8. Open the RStudio session in the browser
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://localhost:$PORT/?token=$SECRET"
elif command -v open >/dev/null 2>&1; then
    open "http://localhost:$PORT/?token=$SECRET"
else
    echo "Please open your browser and go to: http://localhost:$PORT/?token=$SECRET"
fi
