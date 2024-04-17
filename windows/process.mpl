# Copyright (C) Matway Burkow
#
# This repository and all its contents belong to Matway Burkow (referred here and below as "the owner").
# The content is for demonstration purposes only.
# It is forbidden to use the content or any part of it for any purpose without explicit permission from the owner.
# By contributing to the repository, contributors acknowledge that ownership of their work transfers to the owner.

"control.&&"            use
"control.Cond"          use
"control.Cref"          use
"control.Nat32"         use
"control.ensure"        use
"control.when"          use

"kernel32.CloseHandle"         use
"kernel32.CreateProcessW"      use
"kernel32.GetExitCodeProcess"  use
"kernel32.GetLastError"        use
"kernel32.INFINITE"            use
"kernel32.PROCESS_INFORMATION" use
"kernel32.SECURITY_ATTRIBUTES" use
"kernel32.STARTUPINFOW"        use
"kernel32.STILL_ACTIVE"        use
"kernel32.WAIT_OBJECT_0"       use
"kernel32.WaitForSingleObject" use

"unicode.utf16" use

Process: [{
  SCHEMA_NAME: "Process" virtual;

  startupInfo:               STARTUPINFOW;
  processInformation:        PROCESS_INFORMATION;
  processSecurityAttributes: SECURITY_ATTRIBUTES Cref; # We want it to be Nil by default
  threadSecurityAttributes:  SECURITY_ATTRIBUTES Cref; #

  init: [startupInfo storageSize Nat32 cast @startupInfo.!cb];

  start: [
    command:;
    result:
      @processInformation
      startupInfo
      0nx
      0nx
      0n32
      0
      threadSecurityAttributes
      processSecurityAttributes
      command.data storageAddress
      0nx
      CreateProcessW 0 = ~
    ;

    result
  ];

  tillActive: [INFINITE processInformation.hProcess WaitForSingleObject WAIT_OBJECT_0 =];

  close: [
    processInformation.hProcess CloseHandle 0 = ~ [processInformation.hThread CloseHandle 0 = ~] &&
  ];

  exitCode: [
    out:;
    errorTrait: @out processInformation.hProcess GetExitCodeProcess;
    errorTrait 0 = ~
  ];
}];

# Start 'process' represented by 'command'
# in:
#   command
# out:
#   process
#
# Examples:
#   1) "program" startProcess.closeInactive
#
#   2) "program programArgument" startProcess.closeInactive
#
#   3) program: "program" startProcess;
#      program.operationSucceed [program.closeInactive] [
#        ("Failed to start program: " program.operationError) printList
#      ] if
#
#   4) program: "program" startProcess;
#      program.tillActive
#      exitCode: program.exitCode;
#      program.close
startProcess: [
  command:;
  {
    process:            Process;
    command:            command utf16;
    operationErrorCode: Nat32;
    toBeClosed:         Cond;

    operationError: [operationErrorCode new];

    operationSucceed: [operationError 0n32 =];

    updateOperationError: [
      determiner:;
      determiner ~ [GetLastError !operationErrorCode] when
    ];

    doNotClose: [FALSE !toBeClosed];

    tillActive: [process.tillActive updateOperationError];

    closeInactive: [
      tillActive
      operationSucceed [close] when
    ];

    close: [
      process.close updateOperationError
      operationSucceed [doNotClose] when
    ];

    # NOTE: There is a corner case. If process did exit with status code 259, the function will report that the process is active
    stillActive: [exitCode STILL_ACTIVE =];

    exitCode: [
      status: Nat32;
      [@status process.exitCode] "[exitCode] failed" ensure
      status
    ];

    INIT: [];

    DIE: [
      [toBeClosed ~] "Handles are not closed" ensure
    ];

    [
      @process.init
      @command @process.start updateOperationError
      operationSucceed !toBeClosed
    ] call
  }
];