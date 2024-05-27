# This file is generated by SciPy's build process
# It contains system_info results at the time of building this package.
from enum import Enum

__all__ = ["show"]
_built_with_meson = True


class DisplayModes(Enum):
    stdout = "stdout"
    dicts = "dicts"


def _cleanup(d):
    """
    Removes empty values in a `dict` recursively
    This ensures we remove values that Meson could not provide to CONFIG
    """
    if isinstance(d, dict):
        return { k: _cleanup(v) for k, v in d.items() if v != '' and _cleanup(v) != '' }
    else:
        return d


CONFIG = _cleanup(
    {
        "Compilers": {
            "c": {
                "name": "gcc",
                "linker": r"ld.bfd",
                "version": "10.3.0",
                "commands": r"cc",
                "args": r"",
                "linker args": r"",
            },
            "cython": {
                "name": r"cython",
                "linker": r"cython",
                "version": r"3.0.10",
                "commands": r"cython",
                "args": r"",
                "linker args": r"",
            },
            "c++": {
                "name": "gcc",
                "linker": r"ld.bfd",
                "version": "10.3.0",
                "commands": r"c++",
                "args": r"",
                "linker args": r"",
            },
            "fortran": {
                "name": "gcc",
                "linker": r"ld.bfd",
                "version": "10.3.0",
                "commands": r"gfortran",
                "args": r"",
                "linker args": r"",
            },
            "pythran": {
                "version": r"0.15.0",
                "include directory": r"C:\Users\runneradmin\AppData\Local\Temp\pip-build-env-dpkmimdm\overlay\Lib\site-packages/pythran"
            },
        },
        "Machine Information": {
            "host": {
                "cpu": r"x86_64",
                "family": r"x86_64",
                "endian": r"little",
                "system": r"windows",
            },
            "build": {
                "cpu": r"x86_64",
                "family": r"x86_64",
                "endian": r"little",
                "system": r"windows",
            },
            "cross-compiled": bool("False".lower().replace('false', '')),
        },
        "Build Dependencies": {
            "blas": {
                "name": "openblas",
                "found": bool("True".lower().replace('false', '')),
                "version": "0.3.27",
                "detection method": "pkgconfig",
                "include directory": r"/c/opt/64/include",
                "lib directory": r"/c/opt/64/lib",
                "openblas configuration": r"USE_64BITINT= DYNAMIC_ARCH=1 DYNAMIC_OLDER= NO_CBLAS= NO_LAPACK= NO_LAPACKE= NO_AFFINITY=1 USE_OPENMP= ZEN MAX_THREADS=24",
                "pc file directory": r"c:/opt/64/lib/pkgconfig",
            },
            "lapack": {
                "name": "openblas",
                "found": bool("True".lower().replace('false', '')),
                "version": "0.3.27",
                "detection method": "pkgconfig",
                "include directory": r"/c/opt/64/include",
                "lib directory": r"/c/opt/64/lib",
                "openblas configuration": r"USE_64BITINT= DYNAMIC_ARCH=1 DYNAMIC_OLDER= NO_CBLAS= NO_LAPACK= NO_LAPACKE= NO_AFFINITY=1 USE_OPENMP= ZEN MAX_THREADS=24",
                "pc file directory": r"c:/opt/64/lib/pkgconfig",
            },
            "pybind11": {
                "name": "pybind11",
                "version": "2.12.0",
                "detection method": "config-tool",
                "include directory": r"unknown",
            },
        },
        "Python Information": {
            "path": r"C:\Users\runneradmin\AppData\Local\Temp\cibw-run-7repr1i9\cp310-win_amd64\build\venv\Scripts\python.exe",
            "version": "3.10",
        },
    }
)


def _check_pyyaml():
    import yaml

    return yaml


def show(mode=DisplayModes.stdout.value):
    """
    Show libraries and system information on which SciPy was built
    and is being used

    Parameters
    ----------
    mode : {`'stdout'`, `'dicts'`}, optional.
        Indicates how to display the config information.
        `'stdout'` prints to console, `'dicts'` returns a dictionary
        of the configuration.

    Returns
    -------
    out : {`dict`, `None`}
        If mode is `'dicts'`, a dict is returned, else None

    Notes
    -----
    1. The `'stdout'` mode will give more readable
       output if ``pyyaml`` is installed

    """
    if mode == DisplayModes.stdout.value:
        try:  # Non-standard library, check import
            yaml = _check_pyyaml()

            print(yaml.dump(CONFIG))
        except ModuleNotFoundError:
            import warnings
            import json

            warnings.warn("Install `pyyaml` for better output", stacklevel=1)
            print(json.dumps(CONFIG, indent=2))
    elif mode == DisplayModes.dicts.value:
        return CONFIG
    else:
        raise AttributeError(
            f"Invalid `mode`, use one of: {', '.join([e.value for e in DisplayModes])}"
        )
