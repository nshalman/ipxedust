#!/usr/bin/env bash
# This script handles all the steps needed to
# download and compile ipxe from source.

set -eux

#XXX Workaround for https://github.com/ipxe/ipxe/issues/606
CERT=ca.pem,isrgrootx1.pem,lets-encrypt-r3.pem
TRUST=ca.pem,isrgrootx1.pem,lets-encrypt-r3.pem

#XXX Workaround for netboot.xyz
VERSION=2.x

# build_ipxe will run the make target in the upstream ipxe source
# that will build an ipxe binary.
function build_ipxe() {
    local ipxe_dir="$1"
    local ipxe_bin="$2"
    local env_opts="$3"
    local embed_path="$4"

    if [ -z "${env_opts}" ]; then
        make -C "${ipxe_dir}"/src EMBED="${embed_path}" CERT="${CERT}" TRUST="${TRUST}" VERSION=${VERSION} "${ipxe_bin}"
    else
        make -C "${ipxe_dir}"/src "${env_opts}" EMBED="${embed_path}" CERT="${CERT}" TRUST="${TRUST}" VERSION=${VERSION} "${ipxe_bin}"
    fi
}

# mv_embed_into_build will move an ipxe script into a location available
# to the ipxe build so that it can be embedded into an ipxe binary.
function mv_embed_into_build() {
    local embed_path="$1"
    local ipxe_dir="$2"

    cp -a "${embed_path}" "${ipxe_dir}"/src/embed.ipxe
}

# make_local_empty will delete any custom ipxe header files,
# putting the ipxe src back to a known good/clean state.
function make_local_empty() {
    local ipxe_dir="$1" 

    rm -rf "${ipxe_dir}"/src/config/local/*
}

# copy_common_files will copy common custom header files into the ipxe src path.
function copy_common_files() {
    local ipxe_dir="$1" 
    cp -a binary/script/ipxe-customizations/colour.h "${ipxe_dir}"/src/config/local/
    cp -a binary/script/ipxe-customizations/common.h "${ipxe_dir}"/src/config/local/
    cp -a binary/script/ipxe-customizations/console.h "${ipxe_dir}"/src/config/local/
    cp -a binary/script/ipxe-customizations/crypto.h "${ipxe_dir}"/src/config/local/
    #XXX Workaround for https://github.com/ipxe/ipxe/issues/606
    cp -a binary/script/ipxe-customizations/{ca.pem,isrgrootx1.pem,lets-encrypt-r3.pem} "${ipxe_dir}"/src
}

# copy_custom_files will copy in any custom header files based on a requested ipxe binary.
function copy_custom_files() {
    local ipxe_dir="$1"
    local ipxe_bin="$2"

    case "${ipxe_bin}" in
    bin/undionly.kpxe)
    	cp binary/script/ipxe-customizations/general.undionly.h "${ipxe_dir}"/src/config/local/general.h
    	;;
    bin/ipxe.lkrn)
    	cp binary/script/ipxe-customizations/general.undionly.h "${ipxe_dir}"/src/config/local/general.h
    	;;
    bin-x86_64-efi/ipxe.efi)
    	cp binary/script/ipxe-customizations/general.efi.h "${ipxe_dir}"/src/config/local/general.h
        cp binary/script/ipxe-customizations/isa.h "${ipxe_dir}"/src/config/local/isa.h
    	;;
    bin-arm64-efi/snp.efi)
    	cp binary/script/ipxe-customizations/general.efi.h "${ipxe_dir}"/src/config/local/general.h
    	;;
    bin-x86_64-efi/ipxe.iso)
    	cp binary/script/ipxe-customizations/general.efi.h "${ipxe_dir}"/src/config/local/general.h
    	cp binary/script/ipxe-customizations/isa.h "${ipxe_dir}"/src/config/local/isa.h
    	;;
    *) echo "unknown binary: ${ipxe_bin}" >&2 && exit 1 ;;
    esac
}

# customize_aarch_build will modify a make file for arm64 builds.
# see http://lists.ipxe.org/pipermail/ipxe-devel/2018-August/006254.html .
function customize_aarch_build() {
    local ipxe_dir="$1"
    # http://lists.ipxe.org/pipermail/ipxe-devel/2018-August/006254.html
    sed -i.bak '/^WORKAROUND_CFLAGS/ s|^|#|' "${ipxe_dir}"/src/arch/arm64/Makefile
}

# customize orchestrates the process for adding custom headers to an ipxe compile.
function customize() {
    local ipxe_dir="$1"
    local ipxe_bin="$2"

    make_local_empty "${ipxe_dir}"
    copy_common_files "${ipxe_dir}"
    copy_custom_files "${ipxe_dir}" "${ipxe_bin}"
    customize_aarch_build "${ipxe_dir}"
}

function hasType() {
    if [ -z "$(type type)" ]; then
        echo "type command not found"
        return 1
    fi
}

function hasUname() {
    if [ -z "$(type uname)" ]; then
        echo "uname command not found"
        return 1
    fi
}

function hasNixShell() {
    if [ -z "$(type nix-shell)" ]; then
        echo "nix-shell command not found"
        return 1
    fi
}

function setup_build_dir() {
    local src_dir=$1
    local build_dir=$2

    rm -rf "${build_dir}"
    cp -a "${src_dir}" "${build_dir}"
}

# main function orchestrating a full ipxe compile.
function main() {
    local bin_path=${1}
    local ipxe_sha_or_tag=${2}
    local final_path=${3}
    local env_opts=${4}
    local embed_path=${5}

    # check for prerequisites
    hasType
    hasUname
    # while nix-shell is not used in this script,
    # we should be in nix-shell for the iPXE build.
    hasNixShell

    local ipxe_src=upstream-${ipxe_sha_or_tag}
    local build_dir=${ipxe_src}-${final_path##*/}

    setup_build_dir "${ipxe_src}" "${build_dir}"
    mv_embed_into_build "${embed_path}" "${build_dir}"
    customize "${build_dir}" "${bin_path}"

    build_ipxe "${build_dir}" "${bin_path}" "${env_opts}" "embed.ipxe"
    cp -a "${build_dir}/src/${bin_path}" "${final_path}"
}

main "$1" "$2" "$3" "${4:-}" "${5:-binary/script/embed.ipxe}"
