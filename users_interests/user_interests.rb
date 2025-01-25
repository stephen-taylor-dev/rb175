require "sinatra"
require "sinatra/reloader"
require "tilt/erubi"
require "yaml"

before do
  @users = YAML.load_file("users.yaml")
  @user_names = @users.keys.map(&:to_s)
end

get "/" do
  redirect "/users"
end

get "/users" do
  erb :users
end

get "/:user" do
  name = params[":user"].to_sym
  @name = name.to_s.capitalize
  @email = @users[name][:email]
  @interests = @users[name][:interests].join(', ')
  erb :user
end

helpers do

  def count_interests
    @users.reduce(0) do |total, (user, values)|
      total + values[:interests].size
    end
  end

end