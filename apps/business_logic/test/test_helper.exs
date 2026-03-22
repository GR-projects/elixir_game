# Start ExUnit with the default options
ExUnit.start()

# Configure Mox for testing
Mox.defmock(TestHandler, for: BusinessLogic.DelayedTask.Registry)
Mox.defmock(FailingHandler, for: BusinessLogic.DelayedTask.Registry)

# Set Mox global mode to avoid having to pass the mock explicitly
Mox.Server.start_link([])
