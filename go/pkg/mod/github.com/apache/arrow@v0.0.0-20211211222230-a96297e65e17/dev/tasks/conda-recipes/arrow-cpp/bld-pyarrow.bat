@echo on
pushd "%SRC_DIR%"\python

@rem the symlinks for cmake modules don't work here
@rem NOTE: In contrast to conda-forge, they work here as we clone from git.
@rem del cmake_modules\BuildUtils.cmake
@rem del cmake_modules\SetupCxxFlags.cmake
@rem del cmake_modules\CompilerInfo.cmake
@rem del cmake_modules\FindNumPy.cmake
@rem del cmake_modules\FindPythonLibsNew.cmake
@rem copy /Y "%SRC_DIR%\cpp\cmake_modules\BuildUtils.cmake" cmake_modules\
@rem copy /Y "%SRC_DIR%\cpp\cmake_modules\SetupCxxFlags.cmake" cmake_modules\
@rem copy /Y "%SRC_DIR%\cpp\cmake_modules\CompilerInfo.cmake" cmake_modules\
@rem copy /Y "%SRC_DIR%\cpp\cmake_modules\FindNumPy.cmake" cmake_modules\
@rem copy /Y "%SRC_DIR%\cpp\cmake_modules\FindPythonLibsNew.cmake" cmake_modules\

SET ARROW_HOME=%LIBRARY_PREFIX%
SET SETUPTOOLS_SCM_PRETEND_VERSION=%PKG_VERSION%
SET PYARROW_BUILD_TYPE=release
SET PYARROW_WITH_S3=1
SET PYARROW_WITH_HDFS=1
SET PYARROW_WITH_DATASET=1
SET PYARROW_WITH_FLIGHT=1
SET PYARROW_WITH_GANDIVA=1
SET PYARROW_WITH_PARQUET=1
SET PYARROW_CMAKE_GENERATOR=Ninja

:: Enable CUDA support
if "%cuda_compiler_version%"=="None" (
    set "PYARROW_WITH_CUDA=0"
) else (
    set "PYARROW_WITH_CUDA=1"
)

%PYTHON%   setup.py ^
           build_ext ^
           install --single-version-externally-managed ^
                   --record=record.txt
if errorlevel 1 exit 1
popd

if [%PKG_NAME%] == [pyarrow] (
    rd /s /q %SP_DIR%\pyarrow\tests
)
