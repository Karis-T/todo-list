require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "sinatra/content_for"
require "sinatra/reloader" if development?

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    completed, uncompleted = lists.partition {|list| list_complete?(list)}
    uncompleted.each(&block)
    completed.each(&block)
  end

  def sort_todos(todos, &block)
    completed, uncompleted = todos.partition {|todo| todo[:completed]}
    uncompleted.each(&block)
    completed.each(&block)
  end
end

def load_list(id)
  list = session[:lists].find{ |list| list[:id] == id }
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
  halt
end


# Return an error message if name invalid. return nil if name vaild
def error_for_list_name(name)
  if session[:lists].any? { |list| name == list[:name] }
    "List name must be unique."
  elsif !(1..100).cover?(name.length)
    "List name must be between 1 and 100 characters."
  end
end

# Return an error message if name invalid. return nil if name vaild
def error_for_todo(name)
  if !(1..100).cover?(name.length)
    "todo name must be between 1 and 100 characters."
  end
end

def next_element_id(elements)
  max = elements.map { |todo| todo[:id] }.max || 0
  max + 1
end


before do
  session[:lists] ||= []
end

get "/" do
  redirect("/lists")
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb(:lists, layout: :layout)
end

# Render the new list form
get "/lists/new" do
  erb(:new_list, layout: :layout)
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb(:new_list, layout: :layout)
  else
    id = next_element_id(session[:lists])
    session[:lists] << {id: id, name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect("/lists")
  end
end

#render individual list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb(:list, layout: :layout)
end

# edit existing todo list
get "/lists/:id/edit" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb(:edit_list, layout: :layout)
end

# update existing todo list
post "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb(:edit_list, layout: :layout)
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect("/lists/#{@list_id}")
  end
end

# Delete todo list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }
  session[:success] = "The list has been deleted."
  redirect("/lists")
end

# add a new todo to a list
post "/lists/:list_id/todos" do
  todo_name = params[:todo].strip
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  error = error_for_todo(todo_name)
  if error
    session[:error] = error
    erb(:list, layout: :layout)
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << {id: id, name: todo_name, completed: false}
    session[:success] = "The todo was added."
    redirect("/lists/#{@list_id}")
  end
end

# delete a todo
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id }
  session[:success] = "The todo has been deleted."
  redirect("/lists/#{@list_id}")
end

# update the status of a todo
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed
  session[:success] = "The todo has been updated."
  redirect("/lists/#{@list_id}")
end

# complete all todos for a list
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list[:todos].each { |todo| todo[:completed] = true }
  session[:success] = "All todos have been completed."
  redirect("/lists/#{@list_id}")
end


# GET  /lists       -> view all lists
# GET  /lists/new   -> get new list form
# POST /lists       -> create a new list
# GET  /lists/1     -> View a single list

# resourced based
# modifying a list object
# don't guess what the url DOES
# its about what the URL IS
# work back the other way