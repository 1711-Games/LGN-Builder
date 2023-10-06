import LGNLog

LoggingSystem.bootstrap(LGNLogger.init)
LGNLogger.logLevel = .debug
LGNLogger.hideLabel = true
LGNLogger.hideTimezone = true

Build.main()
