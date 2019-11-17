defmodule TodoList do
  defstruct auto_id: 1, entries: %{}

  def new(entries \\ []) do
    Enum.reduce(
      entries,
      %TodoList{},
      fn entry, todo_list ->
        add_entry(todo_list, entry)
      end
    )
  end

  def add_entry(todo_list, entry) do
    entry = Map.put(entry, :id, todo_list.auto_id)
    new_entries = Map.put(todo_list.entries, todo_list.auto_id, entry)
    %TodoList{todo_list | entries: new_entries, auto_id: todo_list.auto_id + 1}
  end

  def entries(todo_list, date) do
    todo_list.entries
    |> Stream.filter(fn {_, entry} -> entry.date == date end)
    |> Enum.map(fn {_, entry} -> entry end)
  end

  def update_entry(todo_list, id, updater) do
    case Map.fetch(todo_list.entries, id) do
      :error ->
        todo_list

      {:ok, old_entry} ->
        new_entry = updater.(old_entry)
        new_entries = Map.put(todo_list.entries, new_entry.id, new_entry)
        %TodoList{todo_list | entries: new_entries}
    end
  end

  def delete(todo_list, id) do
    %TodoList{todo_list | entries: Map.delete(todo_list.entries, id)}
  end
end

defmodule ServerProcess do
  def start(callback_module) do
    spawn(fn ->
      state = callback_module.init()
      loop(callback_module, state)
    end)
  end

  def loop(callback_module, state) do
    receive do
      {:call, caller, request} ->
        {response, new_state} = callback_module.handle_call(request, state)

        send(caller, {:response, response})

        loop(callback_module, new_state)

      {:cast, request} ->
        new_state = callback_module.handle_cast(request, state)

        loop(callback_module, new_state)
    end
  end

  def cast(server_pid, request) do
    send(server_pid, {:cast, request})
  end

  def call(server_pid, request) do
    send(server_pid, {:call, self(), request})

    receive do
      {:response, response} -> response
    end
  end
end

defmodule TodoServer do
  def start, do: ServerProcess.start(__MODULE__)

  def init, do: TodoList.new()

  def entries(server_pid, date) do
    ServerProcess.call(server_pid, {:entries, date})
  end

  def add(server_pid, entry) do
    ServerProcess.cast(server_pid, {:add, entry})
  end

  def delete(server_pid, id) do
    ServerProcess.cast(server_pid, {:delete, id})
  end

  def update(server_pid, id, updater) do
    ServerProcess.cast(server_pid, {:update, id, updater})
  end

  def handle_call({:entries, date}, todo_list) do
    {TodoList.entries(todo_list, date), todo_list}
  end

  def handle_cast({:add, entry}, todo_list) do
    TodoList.add_entry(todo_list, entry)
  end

  def handle_cast({:delete, id}, todo_list) do
    TodoList.delete(todo_list, id)
  end

  def handle_cast({:update, id, updater}, todo_list) do
    TodoList.update_entry(todo_list, id, updater)
  end
end
