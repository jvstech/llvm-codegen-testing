cmake_minimum_required(VERSION 3.20)

project(CodegenTesting LANGUAGES NONE)

set(LLVM_SOURCE_DIR "" CACHE PATH "Path to the LLVM source directory")
set(LLVM_DIR "" CACHE PATH "Path to where LLVM is installed")
set(LLC_EXE "" CACHE FILEPATH "Path to the llc tool binary")
set(PASSES "prologepilog" CACHE STRING
  "Semicolon-separated list of codegen passes to stop and start in order")
set(LLVM_TARGETS "" CACHE STRING "Semicolon-separated list of codegen backends to test")
set(TEST_DIR "" CACHE PATH "Path containing .ll files for direct testing")

####################################################################################################

find_package(Python3 COMPONENTS Interpreter REQUIRED)

if (NOT LLVM_SOURCE_DIR AND NOT TEST_DIR)
  message(FATAL_ERROR "Neither LLVM_SOURCE_DIR nor TEST_DIR are set.")
endif()

if (NOT TEST_DIR)
  if (NOT IS_DIRECTORY "${LLVM_SOURCE_DIR}")
    message(FATAL_ERROR "LLVM_SOURCE_DIR is set to a non-existent path: ${LLVM_SOURCE_DIR}")
  endif()
endif()

if (NOT LLVM_DIR AND NOT LLC_EXE)
  message(FATAL_ERROR "Neither LLVM_DIR nor LLC_EXE are set.")
endif()

if (NOT LLC_EXE)
  if (NOT IS_DIRECTORY "${LLVM_DIR}")
    message(FATAL_ERROR "LLVM_DIR is set to a non-existent path: ${LLVM_DIR}")
  endif()

  cmake_path(APPEND LLVM_DIR "bin" OUTPUT_VARIABLE binPath)
  if (NOT IS_DIRECTORY "${binPath}")
    message(FATAL_ERROR "'bin' directory not found in LLVM_DIR (${LLVM_DIR})")
  endif()

  cmake_path(APPEND binPath "llc${CMAKE_EXECUTABLE_SUFFIX}" OUTPUT_VARIABLE LLC_EXE)
endif()

if (NOT EXISTS "${LLC_EXE}")
  message(FATAL_ERROR "LLC_EXE is set to the non-existent path ${LLC_EXE}")
endif()

####################################################################################################

# Gather the list of testable IR files from the LLVM source tree.
if (LLVM_TARGETS)
  list(APPEND targets -t ${LLVM_TARGETS})
endif()

set(testListFile "${PROJECT_BINARY_DIR}/found_tests.txt")
message(STATUS "Gathering list of testable IR files")
execute_process(
  COMMAND
    ${Python3_EXECUTABLE} "${PROJECT_SOURCE_DIR}/scripts/find-test-ll.py" "${LLVM_SOURCE_DIR}" 
    ${targets}
  RESULT_VARIABLE findTestsResult
  OUTPUT_FILE "${testListFile}"
  OUTPUT_STRIP_TRAILING_WHITESPACE)

if (NOT "${findTestsResult}" STREQUAL "0")
  message(FATAL_ERROR "Failed to gether list of testable IR files")
endif()

set(baseOutputDir "${PROJECT_BINARY_DIR}/output")

set(reportFile "${PROJECT_BINARY_DIR}/test_results.txt")
file(WRITE "${reportFile}" "")
set(statusFile "${baseOutputDir}/test_status.txt")
add_custom_target(check-results ALL
  COMMAND
    ${CMAKE_COMMAND} -DREPORT_FILE=${reportFile} -DSTATUS_FILE=${statusFile} 
    -P ${PROJECT_SOURCE_DIR}/scripts/check-results.cmake)

# Read the list of testable IR files and generate command targets for each one.
set(codegenPath)
set(codegenPathLen)

file(STRINGS "${testListFile}" testFiles)
while (testFiles)
  list(POP_FRONT testFiles testFile)
  if (NOT codegenPath)
    string(REGEX REPLACE "^(${LLVM_SOURCE_DIR}.+test/CodeGen/).+" "\\1" codegenPath "${testFile}")
    string(LENGTH "${codegenPath}" codegenPathLen)
  endif()

  cmake_path(GET testFile FILENAME testInputFile)
  string(LENGTH "${testInputFile}" testInputFileLen)
  math(EXPR testInputFileLen "${testInputFileLen}-3")
  string(SUBSTRING "${testInputFile}" 0 ${testInputFileLen} baseTestInputFile)

  # Create the base test name.
  string(SUBSTRING "${testFile}" ${codegenPathLen} -1 testRelPath)
  string(LENGTH "${testRelPath}" testRelPathLen)
  math(EXPR testRelPathLen "${testRelPathLen}-3")
  string(SUBSTRING "${testRelPath}" 0 ${testRelPathLen} baseTestName)
  cmake_path(GET testRelPath PARENT_PATH testDir)
  string(TOLOWER "${baseTestName}" baseTestName)
  string(REGEX REPLACE "[^a-zA-Z0-9]" "_" baseTestName "${baseTestName}")

  list(APPEND passesList ${PASSES})
  while (passesList)
    list(POP_FRONT passesList passName)
    string(REGEX REPLACE "[^a-zA-Z0-9\\-]" "_" passName "${passName}")
    set(testOutputDir "${baseOutputDir}/${testDir}/${passName}")
    file(MAKE_DIRECTORY "${testOutputDir}")
    set(resultFile "${testOutputDir}/${baseTestName}.${passName}.result.txt")
    # Generate the command to run the test script.
    add_custom_command(OUTPUT "${resultFile}"
      COMMAND ${CMAKE_COMMAND}
        ARGS -DLLC=${LLC_EXE} -DPASS=${passName} -DTEST_FILE=${testFile} -DRESULT_FILE=${resultFile}
          -DREPORT_FILE=${reportFile} -DSTATUS_FILE=${statusFile}
          -P ${PROJECT_SOURCE_DIR}/scripts/run-test.cmake
      COMMENT "Testing ${testRelPath} (${passName})")
    set(testName ${passName}_${baseTestName})
    add_custom_target(${testName} ALL
      DEPENDS "${resultFile}")
    add_dependencies(check-results ${testName})
  endwhile()
endwhile()


