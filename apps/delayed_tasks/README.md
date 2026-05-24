# DelayedTasks

A robust, distributed task scheduling system for Elixir applications that allows you to schedule tasks to run at a specific time in the future, with retries and error handling.

## Features

- **Flexible Scheduling**: Schedule tasks to run at specific times in the future
- **Automatic Retries**: Built-in exponential backoff with jitter for failed tasks
- **Persistence**: Tasks are stored in the database for reliability
- **Scalable**: Distributed processing of tasks across nodes
- **Monitoring**: Track task status, attempts, and results
- **Idempotency**: Safe to retry operations without side effects

## Installation

Add `delayed_tasks` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:delayed_tasks, in_umbrella: true}
  ]
end
```

## Usage

### 1. Define a Task Handler

Create a module that implements the `handle_task/1` function:

```elixir
defmodule MyApp.EmailHandler do
  @moduledoc """
  Example handler for sending email tasks.
  """
  
  @behaviour DelayedTasks.Handler
  
  @impl true
  def handle_task(%DelayedTasks.Task{type: :send_email, params: params}) do
    # Your email sending logic here
    case MyApp.Mailer.send(params) do
      :ok -> 
        {:ok, %{sent_at: DateTime.utc_now()}}
        
      {:error, reason} -> 
        {:error, reason}
    end
  end
end
```

### 2. Register Your Handler

Add your handler to the application configuration in `config/config.exs`:

```elixir
config :delayed_tasks, handlers: [
  send_email: MyApp.EmailHandler
]
```

Or register it at runtime:

```elixir
:ok = DelayedTasks.register_handler(:send_email, MyApp.EmailHandler)
```

### 3. Schedule a Task

```elixir
# Schedule a task to run in 5 minutes
execute_at = DateTime.add(DateTime.utc_now(), 300, :second)

{:ok, task} = DelayedTasks.schedule(
  :send_email,
  %{to: "user@example.com", subject: "Hello", body: "This is a test email"},
  execute_at: execute_at,
  max_attempts: 3,
  priority: 10,
  metadata: %{source: "user_123"}
)
```

### 4. Check Task Status

```elixir
# Check the status of a task
case DelayedTasks.status(task_id) do
  {:ok, task} ->
    IO.inspect("Task status: #{task.state}")
    
  {:error, :not_found} ->
    IO.inspect("Task not found")
end
```

### 5. Cancel a Task

```elixir
:ok = DelayedTasks.cancel(task_id)
```

## Configuration

You can configure the DelayedTasks system in `config/config.exs`:

```elixir
config :delayed_tasks,
  # Default max attempts for tasks (default: 3)
  max_attempts: 5,
  
  # Base backoff time in seconds (default: 5)
  base_backoff_seconds: 10,
  
  # Maximum backoff time in seconds (default: 1 hour)
  max_backoff_seconds: 3600,
  
  # How often to check for due tasks in milliseconds (default: 1000)
  check_interval_ms: 5000,
  
  # Batch size for processing due tasks (default: 10)
  batch_size: 20
```

## Testing

When testing code that uses the DelayedTasks system, you can use Mox to mock the handlers:

```elixir
defmodule MyApp.SomeTest do
  use ExUnit.Case, async: true
  import Mox
  
  # Define the mock
  setup :verify_on_exit!
  
  setup do
    # Register a test handler
    :ok = DelayedTasks.register_handler(:test_task, TestHandler)
    :ok
  end
  
  test "schedules and executes a task" do
    # Set up the mock expectation
    expect(TestHandler, :handle_task, fn task ->
      assert task.type == :test_task
      assert task.params == %{key: "value"}
      {:ok, %{result: :success}}
    end)
    
    # Schedule the task
    execute_at = DateTime.add(DateTime.utc_now(), 100, :millisecond)
    {:ok, %{id: task_id}} = 
      DelayedTasks.schedule(:test_task, %{key: "value"}, execute_at: execute_at)
    
    # Wait for the task to execute
    Process.sleep(200)
    
    # Verify the task was completed
    assert {:ok, %{state: :completed}} = DelayedTasks.status(task_id)
  end
end
```

## Error Handling and Retries

The system automatically handles task failures with exponential backoff:

1. When a task fails, it will be retried with increasing delays
2. The delay between retries follows an exponential backoff pattern with jitter
3. After reaching the maximum number of attempts, the task is marked as failed

## Monitoring

You can monitor tasks using the following functions:

```elixir
# List all tasks with a specific state
DelayedTasks.list_tasks_by_state(:scheduled)
DelayedTasks.list_tasks_by_state(:failed)

# Get statistics about tasks
DelayedTasks.stats()
```

## License

MIT
