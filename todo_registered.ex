defmodule TodoServer do
  @name :todo_server

  def start do
    pid = spawn(fn -> loop(TodoList.new()) end)
    Process.register(pid, @name)
  end

  def add_entry(new_entry) do
    send(@name, {:add_entry, new_entry})
  end

  def update_entry(id, updater) do
    send(@name, {:update_entry, {id, updater}})
  end

  def delete_entry(id) do
    send(@name, {:delete_entry, id})
  end

  def entries(date) do
    send(@name, {:entries, self(), date})

    receive do
      {:todo_entries, entries} -> entries
    after
      5000 -> {:error, :timeout}
    end
  end

  defp loop(todo_list) do
    new_todo_list =
      receive do
        message -> process_message(todo_list, message)
      end

    loop(new_todo_list)
  end

  defp process_message(todo_list, {:entries, caller, date}) do
    send(caller, {:todo_entries, TodoList.entries(todo_list, date)})
    todo_list
  end

  defp process_message(todo_list, {:add_entry, new_entry}) do
    TodoList.add_entry(todo_list, new_entry)
  end

  defp process_message(todo_list, {:update_entry, id, updater}}) do
    TodoList.update_entry(todo_list, id, updater)
  end

  defp process_message(todo_list, {:delete_entry, id}) do
    TodoList.delete(todo_list, id)
  end
end

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
    Map.delete(todo_list.entries, id)
  end
end
