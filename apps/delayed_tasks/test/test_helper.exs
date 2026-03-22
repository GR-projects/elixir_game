# Start ExUnit with the default options
ExUnit.start()

# Configure Mox for testing
Mox.defmock(DelayedTasks.TestHandler, for: DelayedTasks.HandlerBehaviour)

# Start the application
Application.ensure_all_started(:mox)
Application.ensure_all_started(:delayed_tasks)

# Configure the application for test environment
Application.put_env(:delayed_tasks, :handlers, [
  test_task: DelayedTasks.TestHandler
])

# Start the handler process
{:ok, _} = DelayedTasks.Handler.start_link()
