#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import glob
import logging
import pathlib
import sys
logger = logging.getLogger(__name__)

def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("llvm",
                      help="Path to LLVM source",
                      metavar="llvm",
                      type=str,
                      nargs='?')
  parser.add_argument("-t", "--targets",
                      help="Target backends to test",
                      nargs='*', 
                      default=[])
  parser.add_argument("-d", "--debug",
                      help="Enable debug output",
                      action="store_const",
                      dest="loglevel",
                      const=logging.DEBUG,
                      default=logging.WARNING)
  parser.add_argument("-v", "--verbose",
                      help="Enable verbose output",
                      action="store_const",
                      dest="loglevel",
                      const=logging.INFO)
  args = parser.parse_args()
  logging.basicConfig(level=args.loglevel,
                      format="%(levelname)s: %(message)s")

  # Ensure the LLVM source directory exists.
  llvm_source_dir = pathlib.Path(args.llvm)
  if (not llvm_source_dir.exists()):
    eprint("Path not found:", llvm_source_dir.resolve())
    sys.exit(1)

  # Get the CodeGen tests directory
  codegen_test_dirs = []
  llvm_test_dir = llvm_source_dir / "test/CodeGen"
  if (not llvm_test_dir.exists()):
    logger.debug(f"Couldn't find test directory {str(llvm_test_dir.resolve())}")
    llvm_test_dir = llvm_source_dir / "llvm/test/CodeGen"
    logger.debug(f"Checking for test directory {str(llvm_test_dir.resolve())}")
    if (not llvm_test_dir.exists()):
      codegen_test_dirs = [llvm_source_dir]
      logger.debug(f"No LLVM codegen test directory found; using {str(llvm_source_dir.resolve())}")
    else:
      logger.info(f"Found test directory {str(llvm_test_dir.resolve())}")
      # Gather the target directories to check.
      if (not args.targets):
        logger.debug("No targets specified; using all available")
        codegen_test_dirs = [x for x in llvm_test_dir.glob("*") if x.is_dir()]
        logger.debug(f"Using targets: {', '.join(map(lambda x: x.name, codegen_test_dirs))}")
      else:
        codegen_test_dirs = list(map(lambda x: (llvm_test_dir / x), args.targets))
        logger.debug(f"Requested targets: {', '.join(args.targets)}")
        # Maker sure all the requested target directories exist.
        for p in codegen_test_dirs:
          if (not p.exists() or not p.is_dir()):
            eprint("Not a valid target:", p.name)
            sys.exit(1)
      logger.info(f"Using {len(codegen_test_dirs)} target{'s'[:len(codegen_test_dirs)^1]}")

      if (len(codegen_test_dirs) == 0):
        logger.info("No targets specified, so no work to do")
        return
      
  # Gather LLVM IR files containing a target triple.
  found_files = 0
  for test_dir in codegen_test_dirs:
    logger.info(f"Searching for testable IR in {test_dir.resolve()}")
    for test_file in test_dir.glob('**/*.ll'):
      logger.debug(f"Checking {test_dir.name}/{test_file.name} ...")
      if (check_file(test_file)):
        print(str(test_file.resolve()))
        found_files += 1

  logger.info(f"Found {found_files} testable file{'s'[:found_files^1]}")

# Reads a file line by line until it finds a target triple specifier.
def check_file(test_file: pathlib.Path) -> bool:
  if (not test_file.exists()):
    eprint("File not found:", str(test_file.resolve()))
    sys.exit(1)

  with test_file.open() as f:
    for line in f:
      # Dumb matching, but it gets the job done.
      if (line.startswith("target triple = ")):
        return True
  return False
  
# Prints to stderr.
def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)

if __name__ == '__main__':
    main()
