require "pg"

class DatabasePersistance
  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todo-lists")
          end
    @logger = logger
  end

  def disconnect
   @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = <<~SQL
      SELECT todolists.*,
        COUNT(todos.id) AS todos_count,
        COUNT(NULLIF(todos.done, true)) AS todos_remaining_count
        FROM todolists
        LEFT JOIN todos ON todos.todolist_id = todolists.id
        WHERE todolists.id = $1
        GROUP BY todolists.id
        ORDER BY todolists.title
    SQL
    result = query(sql, id)

    tuple_to_list_hash(result.first)
  end

  def all_lists
    sql = <<~SQL
      SELECT todolists.*,
        COUNT(todos.id) AS todos_count,
        COUNT(NULLIF(todos.done, true)) AS todos_remaining_count
        FROM todolists
        LEFT JOIN todos ON todos.todolist_id = todolists.id
        GROUP BY todolists.id
        ORDER BY todolists.title
    SQL

    result = query(sql)

    result.map do |tuple|
      tuple_to_list_hash(tuple)
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO todolists (title) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(id)
    todo_sql = "DELETE FROM todos WHERE todolist_id = $1"
    list_sql = "DELETE FROM todolists WHERE id = $1"
    query(todo_sql, id)
    query(list_sql, id)
  end

  def update_list_name(id, new_name)
    sql = "UPDATE todolists SET title = $1 WHERE id = $2"
    query(sql, new_name, id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (title, todolist_id) VALUES ($1, $2)"
    query(sql, todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todos WHERE id = $1 AND todolist_id = $2"
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET done = $1 WHERE id = $2 AND todolist_id = $3"
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET done = true WHERE todolist_id = $1"
    query(sql, list_id)
  end

  def find_todos_for_list(list_id)
    todo_sql = "SELECT * FROM todos WHERE todolist_id = $1"
    todo_result = query(todo_sql, list_id)

    todos = todo_result.map do |todo_tuple|
      { id: todo_tuple["id"].to_i,
        title: todo_tuple["title"],
        done: todo_tuple["done"] == "t" }
    end
  end

  private

  def tuple_to_list_hash(tuple)
    { id: tuple["id"].to_i,
      title: tuple["title"],
      todos_count: tuple["todos_count"].to_i,
      todos_remaining_count: tuple["todos_remaining_count"].to_i }
  end
end
