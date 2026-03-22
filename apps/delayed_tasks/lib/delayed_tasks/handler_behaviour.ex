defmodule DelayedTasks.HandlerBehaviour do
  @moduledoc """
  Defines the behaviour for task handlers.
  
  To implement a task handler, create a module that implements this behaviour:
  
      defmodule MyApp.MyHandler do
        @behaviour DelayedTasks.HandlerBehaviour
        
        @impl true
        def handle_task(%DelayedTasks.Task{type: :my_task, params: params}) do
          # Your task handling logic here
          {:ok, :result}
        end
      end
  """
  
  @type task :: DelayedTasks.Task.t()
  @type result :: {:ok, any()} | {:error, any()}
  
  @doc """
  Handles a task execution.
  
  This function is called when a task is ready to be executed.
  
  ## Parameters
    * `task` - The task to be executed
    
  ## Returns
    * `{:ok, result}` - If the task was executed successfully
    * `{:error, reason}` - If there was an error executing the task
  """
  @callback handle_task(task) :: result
end
