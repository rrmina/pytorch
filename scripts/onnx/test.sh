#!/bin/bash

set -ex

UNKNOWN=()

# defaults
PARALLEL=0

while [[ $# -gt 0 ]]
do
    arg="$1"
    case $arg in
        -p|--parallel)
            PARALLEL=1
            shift # past argument
            ;;
        *) # unknown option
            UNKNOWN+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done
set -- "${UNKNOWN[@]}" # leave UNKNOWN

pip install pytest scipy hypothesis # these are all already satisfied in CI

if [[ $PARALLEL == 1 ]]; then
    pip install pytest-xdist
fi

# realpath might not be available on MacOS
script_path=$(python -c "import os; import sys; print(os.path.realpath(sys.argv[1]))" "${BASH_SOURCE[0]}")
top_dir=$(dirname $(dirname $(dirname "$script_path")))
test_paths=(
    "$top_dir/test/onnx"
)

args=()
args+=("-v")
if [[ $PARALLEL == 1 ]]; then
  args+=("-n")
  args+=("3")
fi

# These exclusions are for tests that take a long time / a lot of GPU
# memory to run; they should be passing (and you will test them if you
# run them locally
pytest "${args[@]}" \
  --ignore "$top_dir/test/onnx/test_pytorch_onnx_onnxruntime.py" \
  --ignore "$top_dir/test/onnx/test_custom_ops.py" \
  --ignore "$top_dir/test/onnx/test_models_onnxruntime.py" \
  --ignore "$top_dir/test/onnx/test_utility_funs.py" \
  --ignore "$top_dir/test/onnx/test_pytorch_onnx_shape_inference.py" \
  "${test_paths[@]}"

# onnxruntime only support py3
# "Python.h" not found in py2, needed by TorchScript custom op compilation.
if [[ "$BUILD_ENVIRONMENT" == *ort_test1* ]]; then
  pytest "${args[@]}" \
    "$top_dir/test/onnx/test_pytorch_onnx_onnxruntime.py::TestONNXRuntime_opset7" \
    "$top_dir/test/onnx/test_pytorch_onnx_onnxruntime.py::TestONNXRuntime_opset8" \
    "$top_dir/test/onnx/test_pytorch_onnx_onnxruntime.py::TestONNXRuntime" \
    "$top_dir/test/onnx/test_custom_ops.py" \
    "$top_dir/test/onnx/test_models_onnxruntime.py" \
    "$top_dir/test/onnx/test_utility_funs.py"
fi
if [[ "$BUILD_ENVIRONMENT" == *ort_test2* ]]; then
  # Update the loop for new opsets
  for i in $(seq 10 12); do
    pytest "${args[@]}" \
      "$top_dir/test/onnx/test_pytorch_onnx_onnxruntime.py::TestONNXRuntime_opset$i"
  done
  pytest "${args[@]}" \
    "$top_dir/test/onnx/test_pytorch_onnx_onnxruntime.py::TestONNXRuntime_opset12_onnx_shape_inference"
fi
