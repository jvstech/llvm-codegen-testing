cmake_minimum_required(VERSION 3.20)

if (NOT REPORT_FILE)
  set(REPORT_FILE "REPORT_FILE is not set.")
endif()

if (NOT EXISTS "${REPORT_FILE}")
  message(FATAL_ERROR "Report file not found: ${REPORT_FILE}")
endif()

if (NOT STATUS_FILE)
  set(STATUS_FILE "STATUS_FILE is not set.")
endif()

if (NOT EXISTS "${STATUS_FILE}")
  message(FATAL_ERROR "Status file not found: ${STATUS_FILE}")
endif()

file(STRINGS "${REPORT_FILE}" reportResults)
string(REGEX MATCHALL "Failed: " reportFailures "${reportResults}")
list(LENGTH reportFailures reportFailures)
list(SORT reportResults)
list(LENGTH reportResults testCount)
message(STATUS "")
foreach (reportResult ${reportResults})
  string(FIND "${reportResult}" "Failed: " failedIdx)
  if (failedIdx EQUAL "0")
    message("${reportResult}")
  endif()
endforeach()
math(EXPR passCount "${testCount}-${reportFailures}")

file(READ "${STATUS_FILE}" statusValue)
file(REMOVE "${STATUS_FILE}")
message(STATUS "")
message(
  "Total tests: ${testCount}\n"
  "Passing:     ${passCount}")
if (NOT statusValue EQUAL "0")
  message(FATAL_ERROR "${reportFailures} test(s) failed.")
endif()
