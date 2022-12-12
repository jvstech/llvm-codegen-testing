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
list(SORT reportResults)
message("Testing results:")
foreach (reportResult ${reportResults})
  message("${reportResult}")
endforeach()

file(READ "${STATUS_FILE}" statusValue)
file(REMOVE "${STATUS_FILE}")
if (NOT statusValue EQUAL "0")
  message(FATAL_ERROR "One or more tests failed.")
endif()
