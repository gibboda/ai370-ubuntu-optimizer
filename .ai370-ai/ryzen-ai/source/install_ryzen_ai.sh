#!/bin/bash

# Copyright (C) 2024 - 2026 Advanced Micro Devices, Inc. All rights reserved.

# Initialize flags and variables
agree_to_eula=0
path_to_venv=""
cpp_path=""
prompt_name="ryzen-ai"
# Parse named parameters
OPTSTRING=":a:p:n:c:l"

while getopts ${OPTSTRING} opt; do
  case ${opt} in
    a)
      agree_to_eula="${OPTARG}"
      ;;
    n)
      assigned_prompt_name="${OPTARG}"
      ;;
    p)
      path_to_venv="${OPTARG}"
      ;;
    c)
      cpp_path="${OPTARG}"
      ;;
    l)
      local_repo='true'
      ;;
    :)
      echo "Option -${OPTARG} requires an argument."
      exit 1
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      echo "Usage: $0 -a yes -p path/to/venv [-l]" 1>&2
      echo "-a <yes|no>  Agree to EULA"
      echo "-n  prompt name of the virtual env"
      echo "-p <path to where Ryzen AI virtualenv is to be installed to>"
      echo "-c <path to where Ryzen AI C++ libs and header files are to be installed to>"
      
      exit 1
      ;;
  esac
done

# Check if user agreed to EULA
if [[ $agree_to_eula == 'yes' ]]
then
        echo "By using this script, you agree to the EULAs given below" 
        echo ""
        echo "  * AMD         - https://account.amd.com/content/dam/account/en/licenses/download/amd-end-user-license-agreement.pdf"
        echo "  * Third Party - https://account.amd.com/content/dam/account/en/licenses/download/ryzen-ai-1.7.1-linux-tpn-license.pdf"
        echo ""
else
        echo "Please read the EULAs given below at"
        echo ""
        echo "  * AMD         - https://account.amd.com/content/dam/account/en/licenses/download/amd-end-user-license-agreement.pdf"
        echo "  * Third Party - https://account.amd.com/content/dam/account/en/licenses/download/ryzen-ai-1.7.1-linux-tpn-license.pdf"
        echo ""
        echo "If you agree to these EULAs, please run the script with the \"-a yes\" flag"
        exit 1
fi
# Check if path_to_venv is set
if [[ -z $path_to_venv ]]
then
    echo "ERROR: Please provide the path to where the virtual environment should be created using the \"-p\" flag."
    exit 1
fi

# Check if path to venv exists
if [[ -d "$path_to_venv" ]]
then
    echo "ERROR: The path \"${path_to_venv}\" to the virtual environment already exists. Please remove and rerun installer."
    echo ""
    echo "          rm -rf ${path_to_venv}"
    echo ""
    echo "ERROR: Installation failed."
    exit 1
fi

# if cpp_path variable is empty, use the value passed to -p
if [[ -z $cpp_path ]]
then
  cpp_path="${path_to_venv}"
else
  # Check if path to cpp_path exists and ask user to remove it if exists
  if [[ -d "$cpp_path" ]]
  then
      echo "ERROR: The path \"${cpp_path}\" to the C++ libraries already exists. Please remove and rerun installer."
      echo ""
      echo "          rm -rf ${cpp_path}"
      echo ""
      echo "ERROR: Installation failed."
      exit 1
  else
      mkdir -p "$cpp_path"
  fi
fi

if [[ $local_repo ]]
then
    echo "The -l flag is deprecated, this script will always use the local wheel folder, continuing..."
fi

wheels_found=$(ls *.whl 2> /dev/null)
if [[ -z "$wheels_found" ]]
then
    echo "ERROR: No wheels found in the current directory."
    echo "ERROR: Please make sure all wheels are present for install."
    exit 1
fi

if [[ -z $assigned_prompt_name ]]
then
    prompt_name="ryzen-ai"
else
    prompt_name=$assigned_prompt_name
fi

# Check if python version is greater than 3.12
echo "Checking python version..."
PYTHON_MAJOR_VERSION=$(python3.12 -c 'import platform; major, minor, patch = platform.python_version_tuple(); print(major);')
PYTHON_MINOR_VERSION=$(python3.12 -c 'import platform; major, minor, patch = platform.python_version_tuple(); print(minor);')
REQ_PYTHON_MAJOR_VERSION=3
REQ_PYTHON_MINOR_VERSION=12
if [[ -z $PYTHON_MAJOR_VERSION ]] || [[ -z $PYTHON_MINOR_VERSION ]]
then
    echo "ERROR: Cannot find python installed. Please install python 3.12."
    exit 1
fi

if [[ "$PYTHON_MAJOR_VERSION" -ne "$REQ_PYTHON_MAJOR_VERSION" ]] || [[ "$PYTHON_MINOR_VERSION" -ne "$REQ_PYTHON_MINOR_VERSION" ]]
then
    echo "ERROR: Please install python ${REQ_PYTHON_MAJOR_VERSION}.${REQ_PYTHON_MINOR_VERSION}. Your python version is $PYTHON_MAJOR_VERSION.$PYTHON_MINOR_VERSION"
    exit 1
fi

echo "Detected python version is $PYTHON_MAJOR_VERSION.$PYTHON_MINOR_VERSION."

# Check if host has at least 8 CPU and 36 GB of RAM
echo "Checking system requirements..."
CPU_COUNT=$(nproc)
RAM_SIZE=$(free -g | awk '/^Mem:/{print $2}')
MIN_CPU_COUNT=8
MIN_RAM_SIZE=36
if [[ $CPU_COUNT -lt $MIN_CPU_COUNT ]] || [[ $RAM_SIZE -lt $MIN_RAM_SIZE ]]
then
    echo "WARNING: Your system has $CPU_COUNT CPU and $RAM_SIZE GB of RAM."
    echo "WARNING: Please make sure your system has at least $MIN_CPU_COUNT CPU and $MIN_RAM_SIZE GB of RAM."
    echo "         Compilation may fail."
    
fi

# Check if path_to_venv has at least 50GB of disk space
mkdir -p "${path_to_venv}"
DISK_SPACE=$(df -BG "$path_to_venv" | awk 'NR==2{print $4}' | sed 's/G//')
MIN_DISK_SPACE=50 # In GB
if [[ $DISK_SPACE -lt $MIN_DISK_SPACE ]]
then
    echo "WARNING: The path to the virtual environment has only $DISK_SPACE GB of disk space."
    echo "WARNING: Please make sure the path to the virtual environment has at least $MIN_DISK_SPACE GB of disk space."
    echo "         Installation may fail."
fi

ARTIFACTORY_FIND_LINKS="."

set -e
echo "Creating python virtual environment..."
python3.12 -m venv "${path_to_venv}" --copies --prompt $prompt_name

PIP_ARGS="--prerelease=allow --find-links ${ARTIFACTORY_FIND_LINKS}"

# Activate the venv
. "${path_to_venv}"/bin/activate

"${path_to_venv}"/bin/pip install uv

"${path_to_venv}"/bin/uv pip install "ryzen-ai>=1.7.0.dev0,<1.8.0.dev0" \
  "device-essentials-strx>=1.5.0.dev0,<1.8.0.dev0" \
  "device-essentials-phx>=1.5.0.dev0,<1.8.0.dev0" \
  ${PIP_ARGS}

"${path_to_venv}"/bin/uv pip uninstall onnxruntime onnxruntime-vitisai onnxruntime-genai onnxruntime-genai-ryzenai

"${path_to_venv}"/bin/uv pip install onnxruntime-vitisai \
  ${PIP_ARGS}

"${path_to_venv}"/bin/uv pip install --no-deps onnxruntime-genai-ryzenai \
  ${PIP_ARGS}

"${path_to_venv}"/bin/uv pip install "accelerate==1.12.0" \
  "datasets==4.5.0" \
  "evaluate==0.4.6" \
  "transformers==4.57.6" \
  "zstandard==0.25.0"

PYTHON_VENV_SITE_PACKAGES=$(ls -d "${path_to_venv}"/lib/python*/site-packages)
echo $PYTHON_VENV_SITE_PACKAGES
ACTIVATE_PATCH="${PYTHON_VENV_SITE_PACKAGES}/ryzen_ai/scripts/activate.patch"
ACTIVATE_PATCH_CSH="${PYTHON_VENV_SITE_PACKAGES}/ryzen_ai/scripts/activate.csh.patch"
patch -u "${path_to_venv}/bin/activate" -i "${ACTIVATE_PATCH}" --verbose
patch -u "${path_to_venv}/bin/activate.csh" -i "${ACTIVATE_PATCH_CSH}" --verbose

echo "Extracting extra voe config and xclbins.."
tar -xf ${ARTIFACTORY_FIND_LINKS}/voe-min.tar.gz -C "${PYTHON_VENV_SITE_PACKAGES}"

echo "Extracting VOE files needed for c++ development to ${cpp_path}..."
tar -xf ${ARTIFACTORY_FIND_LINKS}/voe-cpp.tar.gz -C "${cpp_path}" --strip-components=1

echo "Extracting hybrid-llm files into install location"
tar -xf ${ARTIFACTORY_FIND_LINKS}/hybrid-llm.tar.gz -C "${cpp_path}"
echo "copy hybrid llm files into deployment folder"
cp -a ${cpp_path}/hybrid-llm/hybrid-llm-artifacts/lib/* ${cpp_path}/deployment/lib/
mkdir -p ${cpp_path}/LLM/examples
cp -a ${cpp_path}/hybrid-llm/hybrid-llm-artifacts/examples/* ${cpp_path}/LLM/examples/
# Retry rm to handle NFS/race/cannot remove Directory not empty error
for i in 1 2 3 4 5; do
  rm -rf ${cpp_path}/hybrid-llm && break || true
  sleep 60
done
if [[ -d "${cpp_path}/hybrid-llm" ]]; then
  echo "Error: Could not remove ${cpp_path}/hybrid-llm after retries; Exiting."
  exit 1
fi

echo "Extracting quicktest files into install location"
tar -xf ${ARTIFACTORY_FIND_LINKS}/quicktest.tar.gz -C "${cpp_path}"

echo Now checking packages available...

set +e
packages=("linux-libc-dev" "zip")
errors=0
for package in "${packages[@]}"
do
    echo checking "$package" ...
    dpkg -s "$package" &> /dev/null
    if [[ $? -ne 0 ]]
    then
        echo "Error: $package is not installed. sudo apt install $package"
        errors=$((errors+1))
    fi
done

# Some Ubuntu 22.04 installations may not have /usr/include/asm
if [[ -d "/usr/include/asm-generic" ]] && [[ ! -d "/usr/include/asm" ]]
then
    echo "Warning: /usr/include/asm does not exist."
    echo "Please create a symlink to /usr/include/asm. This will help avoid errors during compilation."
    echo ""
    echo "  sudo ln -s /usr/include/asm-generic /usr/include/asm"
    echo ""
    errors=$((errors+1))
fi

if [[ $errors -gt 0 ]]
then
    echo "There were required post-install actions. please manually perform these actions before using the installed software."
    echo "The install was still successful. There is no need to re-run this script"
fi

echo "Please activate the virtual environment by running the following command:"
echo "bash: "
echo "    source ${path_to_venv}/bin/activate"
echo "csh: "
echo "    source ${path_to_venv}/bin/activate.csh"
echo "Ryzen AI installation complete."
