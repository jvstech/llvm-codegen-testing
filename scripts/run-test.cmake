cmake_minimum_required(VERSION 3.20)

if (NOT LLC AND NOT LLC_EXE AND NOT LLC_EXECUTABLE)
  message(FATAL_ERROR "LLC, LLC_EXE, or LLC_EXECUTABLE must be set to the"
    "path of the LLVM llc binary.")
endif()
  
if (NOT TEST_FILE)
  message(FATAL_ERROR "TEST_FILE must be set to the path of a .ll file.")
elseif (NOT EXISTS "${TEST_FILE}")
  message(FATAL_ERROR "File not found: ${TEST_FILE}")
endif()

cmake_path(GET TEST_FILE FILENAME testFileName)

list(APPEND llcPaths "${LLC}" "${LLC_EXE}" "${LLC_EXECUTABLE}")
while (llcPaths)
  list(POP_FRONT llcPaths llcPath)
  if (NOT llcPath)
    continue()
  endif()
  if (EXISTS "${llcPath}")
    set(LLC "${llcPath}")
    break()
  endif()
endwhile()

if (NOT EXISTS "${LLC}")
  message(FATAL_ERROR "llc tool not found: ${LLC}")
endif()

if (NOT PASS)
  set(PASS "prologepilog")
endif()

if (NOT OUT_DIR)
  set(OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}")
endif()

if (NOT RESULT_FILE)
  set(RESULT_FILE "${OUT_DIR}/${testFileName}.${PASS}.results.txt")
endif()

if (NOT REPORT_FILE)
  set(REPORT_FILE "${OUT_DIR}/test_results.txt")
endif()

if (NOT STATUS_FILE)
  set(STATUS_FILE "${OUT_DIR}/test_status.txt")
endif()

####################################################################################################

execute_process(
  COMMAND ${LLC} -stop-before ${PASS} ${TEST_FILE} -o -
  COMMAND ${LLC} -start-before ${PASS} -x mir - --filetype=null
  RESULTS_VARIABLE testResults
  OUTPUT_VARIABLE testMachineIR
  ERROR_VARIABLE testStdErr)

set(testPassed TRUE)
while (testResults)
  list(POP_FRONT testResults testResult)
  if (NOT testResult STREQUAL "0")
    message("Failed: ${testFileName} (${PASS})")
    file(READ "${TEST_FILE}" testContents)
    file(APPEND "${REPORT_FILE}" "Failed: ${testFileName} (${PASS})\n")
    file(WRITE "${RESULT_FILE}"
      "Input file: ${TEST_FILE}\n"
      "Result: ${testResult}\n"
      "${testStdErr}\n\n"
      "----------------------------------------\n"
      "Input file contents:\n\n"
      "${testContents}\n"
      "----------------------------------------\n"
      "Generated output:\n\n"
      "${testMachineIR}"
      )
    file(WRITE "${STATUS_FILE}" "1")
    unset(testPassed)
    break()
  endif()
endwhile()

if (testPassed)
  if (REPORT_PASSING)
    file(APPEND "${REPORT_FILE}" "Passed: ${testFileName} (${PASS})\n")
  endif()

  file(WRITE "${RESULT_FILE}" "0")
  if (NOT EXISTS "${STATUS_FILE}")
    file(WRITE "${STATUS_FILE}" "0")
  endif()
endif()
