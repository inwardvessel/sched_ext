#! /bin/bash
# SPDX-License-Identifier: GPL-2.0

readonly KSFT_PASS=0
readonly KSFT_FAIL=1
readonly KSFT_SKIP=4
readonly KSFT_TEST=$(basename "${0}" | sed 's/\.sh$//g')

MPTCP_LIB_SUBTESTS=()

# SELFTESTS_MPTCP_LIB_EXPECT_ALL_FEATURES env var can be set when validating all
# features using the last version of the kernel and the selftests to make sure
# a test is not being skipped by mistake.
mptcp_lib_expect_all_features() {
	[ "${SELFTESTS_MPTCP_LIB_EXPECT_ALL_FEATURES:-}" = "1" ]
}

# $1: msg
mptcp_lib_fail_if_expected_feature() {
	if mptcp_lib_expect_all_features; then
		echo "ERROR: missing feature: ${*}"
		exit ${KSFT_FAIL}
	fi

	return 1
}

# $1: file
mptcp_lib_has_file() {
	local f="${1}"

	if [ -f "${f}" ]; then
		return 0
	fi

	mptcp_lib_fail_if_expected_feature "${f} file not found"
}

mptcp_lib_check_mptcp() {
	if ! mptcp_lib_has_file "/proc/sys/net/mptcp/enabled"; then
		echo "SKIP: MPTCP support is not available"
		exit ${KSFT_SKIP}
	fi
}

mptcp_lib_check_kallsyms() {
	if ! mptcp_lib_has_file "/proc/kallsyms"; then
		echo "SKIP: CONFIG_KALLSYMS is missing"
		exit ${KSFT_SKIP}
	fi
}

# Internal: use mptcp_lib_kallsyms_has() instead
__mptcp_lib_kallsyms_has() {
	local sym="${1}"

	mptcp_lib_check_kallsyms

	grep -q " ${sym}" /proc/kallsyms
}

# $1: part of a symbol to look at, add '$' at the end for full name
mptcp_lib_kallsyms_has() {
	local sym="${1}"

	if __mptcp_lib_kallsyms_has "${sym}"; then
		return 0
	fi

	mptcp_lib_fail_if_expected_feature "${sym} symbol not found"
}

# $1: part of a symbol to look at, add '$' at the end for full name
mptcp_lib_kallsyms_doesnt_have() {
	local sym="${1}"

	if ! __mptcp_lib_kallsyms_has "${sym}"; then
		return 0
	fi

	mptcp_lib_fail_if_expected_feature "${sym} symbol has been found"
}

# !!!AVOID USING THIS!!!
# Features might not land in the expected version and features can be backported
#
# $1: kernel version, e.g. 6.3
mptcp_lib_kversion_ge() {
	local exp_maj="${1%.*}"
	local exp_min="${1#*.}"
	local v maj min

	# If the kernel has backported features, set this env var to 1:
	if [ "${SELFTESTS_MPTCP_LIB_NO_KVERSION_CHECK:-}" = "1" ]; then
		return 0
	fi

	v=$(uname -r | cut -d'.' -f1,2)
	maj=${v%.*}
	min=${v#*.}

	if   [ "${maj}" -gt "${exp_maj}" ] ||
	   { [ "${maj}" -eq "${exp_maj}" ] && [ "${min}" -ge "${exp_min}" ]; }; then
		return 0
	fi

	mptcp_lib_fail_if_expected_feature "kernel version ${1} lower than ${v}"
}

__mptcp_lib_result_add() {
	local result="${1}"
	shift

	local id=$((${#MPTCP_LIB_SUBTESTS[@]} + 1))

	MPTCP_LIB_SUBTESTS+=("${result} ${id} - ${KSFT_TEST}: ${*}")
}

# $1: test name
mptcp_lib_result_pass() {
	__mptcp_lib_result_add "ok" "${1}"
}

# $1: test name
mptcp_lib_result_fail() {
	__mptcp_lib_result_add "not ok" "${1}"
}

# $1: test name
mptcp_lib_result_skip() {
	__mptcp_lib_result_add "ok" "${1} # SKIP"
}

# $1: result code ; $2: test name
mptcp_lib_result_code() {
	local ret="${1}"
	local name="${2}"

	case "${ret}" in
		"${KSFT_PASS}")
			mptcp_lib_result_pass "${name}"
			;;
		"${KSFT_FAIL}")
			mptcp_lib_result_fail "${name}"
			;;
		"${KSFT_SKIP}")
			mptcp_lib_result_skip "${name}"
			;;
		*)
			echo "ERROR: wrong result code: ${ret}"
			exit ${KSFT_FAIL}
			;;
	esac
}

mptcp_lib_result_print_all_tap() {
	local subtest

	if [ ${#MPTCP_LIB_SUBTESTS[@]} -eq 0 ] ||
	   [ "${SELFTESTS_MPTCP_LIB_NO_TAP:-}" = "1" ]; then
		return
	fi

	printf "\nTAP version 13\n"
	printf "1..%d\n" "${#MPTCP_LIB_SUBTESTS[@]}"

	for subtest in "${MPTCP_LIB_SUBTESTS[@]}"; do
		printf "%s\n" "${subtest}"
	done
}
