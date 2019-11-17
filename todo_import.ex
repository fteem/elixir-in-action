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

defmodule TodoList.CsvImporter do
  def import(file_path) do
    file_path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.map(fn line -> String.split(line, ",") end)
    |> Stream.map(fn [date, title] -> {parse_date(date), title} end)
    |> Stream.map(fn {{year, month, day}, title} ->
      {:ok, date} = Date.new(year, month, day)

      %{date: date, title: title}
    end)
    |> TodoList.new()
  end

  def parse_date(date) do
    date
    |> String.split("/")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end
end

defimpl Collectable, for: TodoList do
  def into(original) do
    {original, &into_callback/2}
  end

  defp into_callback(todo_list, {:cont, entry}) do
    TodoList.add_entry(todo_list, entry)
  end

  defp into_callback(todo_list, :done), do: todo_list
  defp into_callback(_todo_list, :halt), do: :ok
end
