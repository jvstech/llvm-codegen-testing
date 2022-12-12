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

if (NOT OUT_FILE)
  cmake_path(REPLACE_EXTENSION testFileName LAST_ONLY ".pre.${PASS}.mir" OUTPUT_VARIABLE OUT_FILE)
  set(OUT_FILE "${OUT_DIR}/${OUT_FILE}")
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

if (NOT ERROR_FILE)
  set(ERROR_FILE "${OUT_DIR}/test_errors.txt")
endif()

####################################################################################################

execute_process(
  COMMAND ${LLC} -stop-before ${PASS} ${TEST_FILE} -o ${OUT_FILE}
  RESULT_VARIABLE testResult
  ERROR_VARIABLE testStdErr)

if ("${testResult}" STREQUAL "0")
  execute_process(
    COMMAND ${LLC} -start-before ${PASS} -x mir ${OUT_FILE} --filetype=null
    RESULT_VARIABLE testResult
    ERROR_VARIABLE testStdErr)
endif()

set(testPassed TRUE)
if (NOT testResult STREQUAL "0")
  message("Failed: ${testFileName} (${PASS})")
  if (EXISTS "${OUT_FILE}")
    file(READ "${OUT_FILE}" testMachineIR)
  else()
    set(testMachineIR)
  endif()
  file(APPEND "${REPORT_FILE}" "Failed: ${testFileName} (${PASS})\n")
  string(APPEND resultOutput
    "Input file: ${TEST_FILE}\n"
    "Generated file: ${OUT_FILE}\n"
    "Result: ${testResult}\n"
    "${testStdErr}\n\n"
    "----------------------------------------\n"
    "Generated output:\n\n"
    "${testMachineIR}\n")
  file(WRITE "${RESULT_FILE}"
    "${resultOutput}")
  file(APPEND "${ERROR_FILE}"
    "======================================================================================\n\n"
    "${resultOutput}\n\n")
  file(WRITE "${STATUS_FILE}" "1")
  unset(testPassed)
  unset(resultOutput)
endif()

if (testPassed)
  file(APPEND "${REPORT_FILE}" "Passed: ${testFileName} (${PASS})\n")
  file(WRITE "${RESULT_FILE}" "0")
  if (NOT EXISTS "${STATUS_FILE}")
    file(WRITE "${STATUS_FILE}" "0")
  endif()
endif()
