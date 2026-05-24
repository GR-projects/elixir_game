defmodule DelayedTasks.Handler do
  @moduledoc """
  Handles the registration and lookup of task handlers.
  """
  use GenServer
  require Logger
  
  @behaviour DelayedTasks.HandlerBehaviour
  
  # Client API
  
  @doc """
  Starts the handler registry.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.merge([name: __MODULE__], opts))
  end
  
  @doc """
  Registers a handler for a specific task type.
  """
  @spec register_handler(atom(), module()) :: :ok | {:error, term()}
  def register_handler(type, module) when is_atom(type) and is_atom(module) do
    GenServer.call(__MODULE__, {:register, type, module})
  end
  
  @doc """
  Gets the handler module for a specific task type.
  """
  @spec get_handler(atom()) :: {:ok, module()} | {:error, :not_found}
  def get_handler(type) when is_atom(type) do
    case :ets.lookup(__MODULE__, type) do
      [{^type, module}] -> {:ok, module}
      [] -> {:error, :not_found}
    end
  end
  
  @doc """
  Lists all registered handlers.
  """
  @spec list_handlers() :: [{atom(), module()}]
  def list_handlers do
    :ets.tab2list(__MODULE__)
  end
  
  # Server callbacks
  
  @impl true
  def init(:ok) do
    # Create an ETS table to store handler registrations
    :ets.new(__MODULE__, [:set, :public, :named_table, read_concurrency: true])
    
    # Load handlers from application config
    handlers = Application.get_env(:delayed_tasks, :handlers, [])
    
    # Register all handlers from config
    Enum.each(handlers, fn {type, module} ->
      case Code.ensure_loaded?(module) and function_exported?(module, :handle_task, 1) do
        true ->
          :ets.insert(__MODULE__, {type, module})
          Logger.info("Registered handler for task type: #{inspect(type)} -> #{inspect(module)}")
          
        false ->
          Logger.error("Failed to register handler for type #{inspect(type)}: #{inspect(module)} does not implement handle_task/1")
      end
    end)
    
    {:ok, %{}}
  end
  
  @impl true
  def handle_call({:register, type, module}, _from, state) do
    case Code.ensure_loaded?(module) and function_exported?(module, :handle_task, 1) do
      true ->
        :ets.insert(__MODULE__, {type, module})
        Logger.info("Registered handler for task type: #{inspect(type)} -> #{inspect(module)}")
        {:reply, :ok, state}
        
      false ->
        error_msg = "Handler module #{inspect(module)} must implement the DelayedTasks.HandlerBehaviour behaviour"
        Logger.error(error_msg)
        {:reply, {:error, :invalid_handler}, state}
    end
  end
  
  @impl true
  def handle_call(:list_handlers, _from, state) do
    handlers = :ets.tab2list(__MODULE__)
    {:reply, handlers, state}
  end
  
  # Default handler implementation (can be overridden by actual handlers)
  @impl DelayedTasks.HandlerBehaviour
  def handle_task(%DelayedTasks.Task{type: type}) do
    {:error, "No handler registered for task type: #{inspect(type)}"}
  end
end
