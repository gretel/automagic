#!/usr/bin/env bash
#
# https://github.com/gretel/autobitch
# tom hensel <github@jitter.eu> 2016

# pyenv: the layout pyenv supposes (~/.pyenv)
# - but don't actually require or call pyenv
layout_pyenv() {
    # check if PYENV_ROOT is set
    if ! check_dir "${PYENV_ROOT}"; then
        log_error "⧄ expected PYENV_ROOT to be set!"; return 1;
    fi

    # version string
    local py_ver="${1}"
    check_string "${py_ver}" || return 2;

    # pyenv uses wrapper to support switching versions
    local py_shims="${HOME}/.pyenv/shims"
    check_dir "${py_shims}" || return 3;

    # base path of python installation
    local py_dir="${HOME}/.pyenv/versions/${py_ver}"
    check_dir "${py_dir}" || return 4;

    # python interpreter
    local py_bin_dir="${py_dir}/bin"
    check_exec "${py_bin_dir}/python" || return 5;

    # cleanup
    unset VIRTUAL_ENV PYTHONHOME PYTHONPATH
    # emulate pyenv (be compatible)
    export PYENV_VERSION="${py_ver}"

    # add to PATH
    PATH_add "${py_shims}"
    PATH_add "${py_bin_dir}"
    # and it's manpages
    path_add MANPATH "${py_dir}/share/man"

    # common
    _ready_python
}

# layout_virtualenv: name is bit ambigious - it's does not require virtualenv
# nor in particular the 'activate' script it puts into the virtualenv
# it is emulated here closely - should be very compatible
layout_virtualenv() {
    # cleanup
    unset PYTHONPATH PYENV_VERSION
    if test -z "${PYTHONHOME+_}"; then
        unset PYTHONHOME
    fi

    # path of virtualenv
    local venv_path="${1}"
    check_dir "${venv_path}" || return 1;

    # watch script for changes
    local venv_activate="${venv_path}/bin/activate"
    #watch_file "${venv_activate}"

    # it's all about VIRTUAL_ENV, literally
    export VIRTUAL_ENV="${venv_path}"

    # add it's binaries to PATH
    PATH_add "${venv_path}/bin"

    # common
    _ready_python
}

_ready_python() {
    # sanitize pydoc alias
    alias pydoc=
    pydoc () {
        python -m pydoc "$@"
    }

    # declare startup script if exists
    local python_rc_file="${HOME}/.python/pythonrc.py"
    if test -f "$python_rc_file"; then
        export PYTHONSTARTUP="${python_rc_file}"
    fi

    # enable use of history file
    local python_history_file="${HOME}/.python_history"
    if ! test -f "$python_history_file"; then
        # if there is no history file create it
        touch "${python_history_file}"
    fi
    export PYTHON_HISTORY_FILE="${python_history_file}"
}

# # layout_ry
# layout_ry() {
#     # check if pyenv is in PATH
#     if ! command -v ry >/dev/null; then
#         log_error "⧄ could not find ry in PATH!"; return 1;
#     fi

#     # check if RY_RUBIES is set
#     if ! check_dir "${RY_RUBIES}"; then
#         log_error "⧄ expected RY_RUBIES to be set!"; return 2;
#     fi

#     # cleanup
#     unset RUBYPATH GEM_HOME GEM_PATH

#     # ry sets symlinks to the selected ruby version
#     # therfore, it will only work if these are in PATH
#     local rb_ver="${1}"
#     check_string "${rb_ver}" || return 3;
#     export RUBY_VERSION="${rb_ver}"

#     # ry puts symlinks to the actual ruby version at this location
#     local ry_shims="${PREFIX}/lib/ry/current/bin"
#     check_dir "${ry_shims}" || return 4;
#     PATH_add "${ry_shims}"

#     # if a ruby is found in the local bin - try to use it
#     # - in ry terms this is called 'shell-local ruby'
#     local rb_bin="${PWD}/bin/ruby"
#     if test -x "${rb_bin}"; then
#         # add this location to PATH (with a higher precedence than the shims)
#         PATH_add "${rb_bin}"
#     else
#         # use ry to resolve the path to the selected version
#         rb_bin="$(ry binpath "${rb_ver}")"
#         PATH_add "${rb_bin}"
#     fi
# }

# layout_rubies: emulate common layout used by chruby (~/.rubies, ~/.gem)
layout_rubies() {
    # check if RY_RUBIES is set
    if ! check_dir "${RY_RUBIES}"; then
        log_error "⧄ expected RY_RUBIES to be set!"; return 2;
    fi

    # cleanup
    unset RUBYPATH GEM_HOME GEM_PATH

    # version string
    local rb_ver="${1}"
    check_string "${rb_ver}" || return 1;
    export RUBY_VERSION="${rb_ver}"

    # home of the ruby installation
    local rb_dir="${HOME}/.rubies/${rb_ver}"
    check_string "${rb_ver}" && check_dir "${rb_dir}" || return 1;
    export RUBY_HOME="${rb_dir}"

    # and it's binaries
    local rb_dir_bin="${rb_dir}/bin"
    check_exec "${rb_dir_bin}/ruby" && check_exec "${rb_dir_bin}/gem" || return 1;
    PATH_add "${rb_dir_bin}"

    # as well as the manpages it brings
    local rb_man_dir="${rb_dir}/share/man"
    check_dir "${rb_man_dir}" || return 1;
    path_add MANPATH "${rb_man_dir}"
}

use_auto_ruby () {
    local rb_string
    local rb_ver
    local rb_which
    # TODO: abstraction
    local rb_ver_file="${PWD}/.ruby-version"

    if rb_ver=$(gather_file "${rb_ver_file}"); then
        log_status "⚑ ruby ${rb_ver} required in {$(user_rel_path "${rb_ver_file}")}"
        # TODO: abstraction, switching
        layout rubies "${rb_ver}"
        # layout ry "${rb_ver}"
    fi

    if rb_which="$(which ruby)"; then
        # TODO: use version for comparison
        rb_string=( $(expect_usage "${rb_which} -v" "ruby") )
        log_status "$(tput bold)✓$(tput sgr0) ruby ${rb_string[1]} at {$(user_rel_path "${rb_which}")}"
    else
        # fail
        log_error "⁈ expected ruby at '${rb_which}' to be in PATH!"
    fi

    # watch file
    watch_file "${rb_ver_file}"
}

use_auto_python () {
    local py_string
    local py_ver
    local py_which
    # TODO: abstraction
    local py_ver_file="${PWD}/.python-version"
    local venv_activate="${PWD}/bin/activate"

    # check for local virtualenv
    if test -f "${venv_activate}"; then
        local venv_path="${PWD}"
        log_status "⚑ python virtualenv at {$(user_rel_path "${venv_path}")}"
        layout virtualenv "${venv_path}"
    elif py_ver=$(gather_file "${py_ver_file}"); then
        log_status "⚑ python ${py_ver} required in {$(user_rel_path "${py_ver_file}")}"
        layout pyenv "${py_ver}"
        # TODO: check if venv and bin path match
    fi

    # in PATH?
    py_which="$(which python)"
    if test -x "${py_which}"; then
        local py_string
        py_string=( $(expect_usage "${py_which} -V" "Python ${py_ver}") ) || return 1;
        log_status "$(tput bold)✓$(tput sgr0) python ${py_string[1]} at {$(user_rel_path "${py_which}")}"
    else
        # fail
        log_error "⁈ expected python at '${py_which}' to be in PATH!"
    fi

    # watch files
    watch_file "${py_ver_file}"
    watch_file "${venv_activate}"
}


check_string() {
    if test -z "${1}"; then
        log_error "⧄ argument is expected to be passed."; return 1;
    fi
}

check_dir() {
    if ! test -d "${1}"; then
        log_error "⧄ path '${1}' is expected to exist."; return 1;
    fi
}

check_exec() {
    if ! test -x "${1}"; then
        log_error "⧄ file '${1}' is expected to be executable."; return 1;
    fi
}

gather_file() {
    test -f "${1}" || return 1;
    OLDIFS="$IFS"
    IFS="${IFS}"$'\r'
    wrds=( $(cut -b 1-1024 "${1}") )
    IFS="$OLDIFS"
    echo "${wrds[0]}"
}

expect_usage() {
    local bin="${1}"
    local should="$2"
    local result
    result=$(${bin} 2>&1)
    case "${result}" in
        *"$should"*)
            echo "${result}"
            return 0;
            ;;
        '')
            log_error "⧄ could not find executable in PATH!"
            return 1;
            ;;
        *)
            log_error "⧄ expected output of '${bin}' to match '${should}' but got '${result}'!"
            return 1;
            ;;
    esac
}

get_abbrv_pwd() {
    cwd="$(user_rel_path "${1}")"
    base="${cwd##*/}"
    dir="${cwd%/*}"
    echo "${dir##*/}/$base"
}

auto_log_prefix() {
    local cwd
    cwd="$(get_abbrv_pwd "${1}")"
    export DIRENV_LOG_FORMAT
    DIRENV_LOG_FORMAT=" $(tput setaf 8)[${cwd}]$(tput sgr0) $(tput setaf 7)%s$(tput sgr0)"
}
