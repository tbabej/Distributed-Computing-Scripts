#!/bin/bash

# Copyright © 2020 Teal Dulcet
# wget https://raw.github.com/tdulcet/Distributed-Computing-Scripts/master/gpuowl2.sh -qO - | bash -s --
# ./gpuowl2.sh <Computer number> [PrimeNet User ID] [Computer name] [Type of work] [Idle time to run (mins)]
# ./gpuowl2.sh <N> "$USER" "$HOSTNAME" 150 10
# ./gpuowl2.sh <N> ANONYMOUS

DIR="gpuowl"
DIR1="gpuowl-master"
DIR2="gpuowl-7.2"
DIR3="gpuowl-6"
if [[ $# -lt 1 || $# -gt 5 ]]; then
	echo "Usage: $0 <Computer number> [PrimeNet User ID] [Computer name] [Type of work] [Idle time to run (mins)]" >&2
	exit 1
fi
N=$1
USERID=${2:-$USER}
COMPUTER=${3:-$HOSTNAME}
TYPE=${4:-100}
TIME=${5:-10}
DEVICE=0
RE='^[0-9]+$'
if ! [[ $N =~ $RE ]]; then
	echo "Usage: <Computer number> must be a number" >&2
	exit 1
fi
RE='^([4]|1(0[0124]|5[012345]))$'
if ! [[ $TYPE =~ $RE ]]; then
	echo "Usage: [Type of work] must be a number" >&2
	exit 1
fi
RE='^([0-9]*[.])?[0-9]+$'
if ! [[ $TIME =~ $RE ]]; then
	echo "Usage: [Idle time to run] must be a number" >&2
	exit 1
fi
echo -e "PrimeNet User ID:\t$USERID"
echo -e "Computer name:\t\t$COMPUTER"
echo -e "Type of work:\t\t$TYPE"
echo -e "Idle time to run:\t$TIME minutes\n"
if [[ -e idletime.sh ]]; then
	bash -- idletime.sh
else
	wget https://raw.github.com/tdulcet/Distributed-Computing-Scripts/master/idletime.sh -qO - | bash -s
fi
GPU=$(lspci | grep -i 'vga\|3d\|2d')
if ! echo "$GPU" | grep -iq 'amd\|nvidia\|intel'; then
	echo -e "Please enter your password if prompted.\n"
	sudo update-pciids
	GPU=$(lspci | grep -i 'vga\|3d\|2d')
	if ! echo "$GPU" | grep -iq 'amd\|nvidia\|intel'; then
		echo "$GPU" | sed -n 's/^.*: //p'
		echo "Error: This computer does not have an AMD, Nvidia or Intel GPU" >&2
		exit 1
	fi
fi
if command -v clinfo >/dev/null; then
	if [[ $(clinfo --raw | sed -n 's/^#PLATFORMS *//p') -eq 0 ]]; then
		clinfo
		echo "Error: This computer does not have an OpenCL platform" >&2
		exit 1
	fi
fi
if ! command -v make >/dev/null || ! command -v g++ >/dev/null; then
	echo -e "Installing Make and the GNU C++ compiler"
	echo -e "Please enter your password if prompted.\n"
	sudo apt-get update -y
	sudo apt-get install build-essential -y
fi
if [[ -n "$CXX" ]] && ! command -v "$CXX" >/dev/null; then
	echo "Error: $CXX is not installed." >&2
	exit 1
fi
CXX=${CXX:-g++}
VERSION=$("$CXX" -dumpversion)
RE='^g\+\+'
if [[ $CXX =~ $RE && ${VERSION%%.*} -lt 8 ]]; then
	echo "Error: GpuOwl requires at least the GNU C++ compiler 8 and you have $VERSION" >&2
	exit 1
fi
if ! command -v python3 >/dev/null; then
	echo "Error: Python 3 is not installed." >&2
	exit 1
fi
files=( /usr/include/gmp*.h )
if ! ldconfig -p | grep -iq 'libgmp\.' || ! ldconfig -p | grep -iq 'libgmpxx\.' || ! [[ -f "${files[0]}" ]]; then
	echo -e "Installing the GNU Multiple Precision (GMP) library"
	echo -e "Please enter your password if prompted.\n"
	sudo apt-get update -y
	sudo apt-get install libgmp3-dev -y
fi
if ! ldconfig -p | grep -iq 'libOpenCL\.'; then
	echo -e "Installing the OpenCL library"
	echo -e "Please enter your password if prompted.\n"
	sudo apt-get update -y
	# sudo apt-get install ocl-icd-* opencl-headers clinfo -y
	sudo apt-get install ocl-icd-opencl-dev clinfo -y
fi
TIME=$(echo "$TIME" | awk '{ printf "%g", $1 * 60 }')
if [[ -d "$DIR" && -x "$DIR/$DIR1/gpuowl" && -x "$DIR/$DIR2/gpuowl" && -x "$DIR/$DIR3/gpuowl" ]]; then
	echo -e "GpuOwl is already downloaded\n"
	cd "$DIR"
else
	mkdir "$DIR"
	cd "$DIR"
	if command -v git >/dev/null; then
		echo -e "Downloading GpuOwl\n"
		git clone https://github.com/tbabej/gpuowl.git $DIR1
		cp -r $DIR1/ $DIR2/
		cp -r $DIR1/ $DIR3/
		sed -i 's/--dirty //' $DIR1/Makefile
		echo
		pushd $DIR2 >/dev/null
		git checkout -f -b v7.2-112 d6ad1e0cf5a323fc4e0ee67e79884448a503a818
		sed -i 's/--dirty //' Makefile
		popd >/dev/null
		echo
		pushd $DIR3 >/dev/null
		git checkout -f v6
		sed -i 's/--dirty //' Makefile
		popd >/dev/null
	else
		echo -e "Downloading GpuOwl v6.11\n"
		wget https://github.com/tbabej/gpuowl/archive/v6.tar.gz
		echo -e "\nDecompressing the files\n"
		tar -xzvf v6.tar.gz
		if output=$(curl -s 'https://api.github.com/repos/tbabej/gpuowl/compare/v6.11...v6'); then
			if command -v jq >/dev/null; then
				behind_by=$(echo "$output" | jq '.behind_by')
				sha=$(echo "$output" | jq -r '.base_commit.sha')
			else
				behind_by=$(echo "$output" | python3 -c 'import sys, json; print(json.load(sys.stdin)["behind_by"])')
				sha=$(echo "$output" | python3 -c 'import sys, json; print(json.load(sys.stdin)["base_commit"]["sha"])')
			fi
			sed -i 's/`git describe --long --dirty --always`/v6.11'"-${behind_by}-g${sha::7}"'/' $DIR3/Makefile
		fi
		echo -e "Downloading GpuOwl v7.2-112\n"
		wget https://github.com/tbabej/gpuowl/archive/d6ad1e0cf5a323fc4e0ee67e79884448a503a818.tar.gz
		echo -e "\nDecompressing the files\n"
		tar -xzvf v6.tar.gz
		mv -v gpuowl-d6ad1e0cf5a323fc4e0ee67e79884448a503a818/ $DIR2/
		sed -i 's/`git describe --long --dirty --always`/v7.2-112-gd6ad1e0/' $DIR2/Makefile
		echo -e "\nDownloading the current version of GpuOwl\n"
		wget https://github.com/tbabej/gpuowl/archive/master.tar.gz
		echo -e "\nDecompressing the files\n"
		tar -xzvf master.tar.gz
		if output=$(curl -s 'https://api.github.com/repos/tbabej/gpuowl/tags?per_page=1'); then
			if command -v jq >/dev/null; then
				name=$(echo "$output" | jq -r '.[0].name')
			else
				name=$(echo "$output" | python3 -c 'import sys, json; print(json.load(sys.stdin)[0]["name"])')
			fi
			if output=$(curl -s "https://api.github.com/repos/tbabej/gpuowl/compare/master...$name"); then
				if command -v jq >/dev/null; then
					behind_by=$(echo "$output" | jq '.behind_by')
					sha=$(echo "$output" | jq -r '.base_commit.sha')
				else
					behind_by=$(echo "$output" | python3 -c 'import sys, json; print(json.load(sys.stdin)["behind_by"])')
					sha=$(echo "$output" | python3 -c 'import sys, json; print(json.load(sys.stdin)["base_commit"]["sha"])')
				fi
			fi
			sed -i 's/`git describe --tags --long --dirty --always`/'"${name}${behind_by:+-${behind_by}${sha:+-g${sha::7}}}"'/' $DIR1/Makefile
		fi
	fi
	echo -e "\nSetting up GpuOwl\n"
	sed -i 's/power <= 10/power <= 12/' {"$DIR1"/src,"$DIR2"}/Proof.cpp
	sed -i 's/power > 10/power > 12/' {"$DIR1"/src,"$DIR2"}/Args.cpp
	pushd $DIR3 >/dev/null
	sed -i 's/"DoubleCheck"/"Test"/' Task.h
	sed -i 's/power >= 6 && power <= 10/power > 0 and power <= 12/' ProofSet.h
	sed -i 's/proofPow >= 6 && proofPow <= 10/proofPow > 0 and proofPow <= 12/' Args.cpp
	sed -i 's/< 6 || power > 10/< 1 || power > 12/' Args.cpp
	# sed -i 's/-Wall -O2/-Wall -g -O3/' Makefile
	popd >/dev/null
	for dir in $DIR1 $DIR2 $DIR3; do
		echo
		pushd "$dir" >/dev/null
		# sed -i 's/-O3/-O3 -flto -funsafe-math-optimizations -ffinite-math-only/' Makefile
		sed -i 's/-O3/-O3 -flto -ffinite-math-only/' Makefile
		make -j "$(nproc)"
		# make clean
		rm -f -- *.o
		popd >/dev/null
	done
	pushd $DIR1/build >/dev/null
	rm -- *.o
	mv -v gpuowl ..
	popd >/dev/null
fi
if [[ -f "primenet.py" ]]; then
	echo -e "The PrimeNet script is already downloaded\n"
else
	echo -e "\nDownloading the PrimeNet script\n"
	if [[ -e ../primenet.py ]]; then
		cp -v ../primenet.py .
	else
		wget https://raw.github.com/tdulcet/Distributed-Computing-Scripts/master/primenet.py -nv
	fi
	chmod +x primenet.py
fi
# python3 -m ensurepip --default-pip || true
python3 -m pip install --upgrade pip || true
echo -e "\nInstalling the Requests library\n"
if ! python3 -m pip install requests; then
	if command -v pip3 >/dev/null; then
		pip3 install requests
	else
		echo -e "\nWarning: pip3 is not installed and the Requests library may also not be installed\n"
	fi
fi
mkdir "$N"
cd "$N"
DIR=$PWD
echo "-user $USERID -cpu ${COMPUTER//[[:space:]]/_}" > config.txt
echo -e "\nRegistering computer with PrimeNet\n"
ARGS=()
if command -v clinfo >/dev/null; then
	clinfo=$(clinfo --raw)
	mapfile -t GPU < <(echo "$clinfo" | sed -n 's/.*CL_DEVICE_NAME *//p')
	ARGS+=( --cpu-model="${GPU[DEVICE]//\[*\]}" )
	
	mapfile -t GPU_FREQ < <(echo "$clinfo" | sed -n 's/.*CL_DEVICE_MAX_CLOCK_FREQUENCY *//p')
	ARGS+=( --frequency="${GPU_FREQ[DEVICE]}" )
	
	mapfile -t TOTAL_GPU_MEM < <(echo "$clinfo" | sed -n 's/.*CL_DEVICE_GLOBAL_MEM_SIZE *//p')
	ARGS+=( -m $(( TOTAL_GPU_MEM[DEVICE] / 1024 / 1024 )) )
elif command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null; then
	mapfile -t GPU < <(nvidia-smi --query-gpu=gpu_name --format=csv,noheader)
	ARGS+=( --cpu-model="${GPU[DEVICE]}" )
	
	mapfile -t GPU_FREQ < <(nvidia-smi --query-gpu=clocks.max.gr --format=csv,noheader,nounits | grep -iv 'not supported')
	if [[ -n "$GPU_FREQ" ]]; then
		ARGS+=( --frequency="${GPU_FREQ[DEVICE]}" )
	fi
	
	mapfile -t TOTAL_GPU_MEM < <(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | grep -iv 'not supported')
	if [[ -n "$TOTAL_GPU_MEM" ]]; then
		ARGS+=( -m "${TOTAL_GPU_MEM[DEVICE]}" )
	fi
fi
python3 ../primenet.py -t 0 -T "$TYPE" -u "$USERID" -r 'results.ini' -g -H "$COMPUTER" "${ARGS[@]}"
echo -e "\nStarting PrimeNet\n"
nohup python3 ../primenet.py >> "primenet.out" &
sleep 1
echo -e "\nDownloading GpuOwl benchmarking script\n"
if [[ -e ../../gpuowl-bench.sh ]]; then
	cp -v ../../gpuowl-bench.sh .
else
	wget https://raw.github.com/tdulcet/Distributed-Computing-Scripts/master/gpuowl-bench.sh -nv
fi
sed -i "s/^DEVICE=0/DEVICE=$DEVICE/" gpuowl-bench.sh
chmod +x gpuowl-bench.sh
echo -e "\nRunning self tests\nThis may take a while…\n"
time ./gpuowl-bench.sh ../$DIR3/gpuowl 10000 STATS
time ./gpuowl-bench.sh ../$DIR1/gpuowl 20000 ROE1,ROE2
echo "The benchmark data was written to the 'bench.txt' file"
echo -e "\nDownloading GpuOwl wrapper script\n"
if [[ -e ../../gpuowl-wrapper.sh ]]; then
	cp -v ../../gpuowl-wrapper.sh .
else
	wget https://raw.github.com/tdulcet/Distributed-Computing-Scripts/master/gpuowl-wrapper.sh -nv
fi
mv -v gpuowl{-wrapper.sh,}
sed -i "s/^DEVICE=0/DEVICE=$DEVICE/" gpuowl
sed -i "s/gpuowl-/..\/gpuowl-/" gpuowl
chmod +x gpuowl
echo -e "\nStarting GpuOwl\n"
nohup ./gpuowl -nospin >> "gpuowl.out" &
sleep 1
echo -e "\nSetting it to start if the computer has not been used in the specified idle time and stop it when someone uses the computer\n"
#crontab -l | { cat; echo "cd ${DIR@Q} && nohup ./gpuowl -nospin >> 'gpuowl.out' &"; } | crontab -
#crontab -l | { cat; echo "cd ${DIR@Q} && nohup python3 ../primenet.py >> 'primenet.out' &"; } | crontab -
crontab -l | { cat; echo "* * * * * if who -s | awk '{ print \$2 }' | (cd /dev && xargs -r stat -c '\%U \%X') | awk '{if ('\"\${EPOCHSECONDS:-\$(date +\%s)}\"'-\$2<$TIME) { print \$1\"\t\"'\"\${EPOCHSECONDS:-\$(date +\%s)}\"'-\$2; ++count }} END{if (count>0) { exit 1 }}' >/dev/null; then pgrep -x gpuowl >/dev/null || (cd ${DIR@Q} && exec nohup ./gpuowl -nospin >> 'gpuowl.out' &); pgrep -f '^python3 \.\./primenet\.py' >/dev/null || (cd ${DIR@Q} && exec nohup python3 ../primenet.py >> 'primenet.out' &); else pgrep -x gpuowl >/dev/null && killall -g -INT gpuowl; fi"; } | crontab -
