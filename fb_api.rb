require "sinatra"
require "json"
require "dalli"
require "koala"

class MyApp < Sinatra::Base
	@@app_settings = {
		:app_id => '553554854707855',
		:app_secret => 'e468ba487e77030017bc03503dbaca2f',
		:callback_url => 'http://localhost:9393/validate',
		:permissions => 'publish_stream,read_stream'
	}

	set :cache, Dalli::Client.new
	enable :sessions

	def logged_in?
		return !session[:token].nil?
	end

	def get_post_details post_id, graph
		return graph.get_object(post_id)
	end

	def get_profile_pic user_id
		return "http://graph.facebook.com/#{user_id}/picture?height=64&width=64"
	end

	get '/' do
		token = session[:token]
		puts "Home token = #{token}"
	
		if logged_in?
			# @name=[]
			puts "logged in"
			graph = Koala::Facebook::API.new(token)
			user = graph.get_object("me")
			@feed=settings.cache.get('feed_key')
			
			if @feed.nil?
			@feed = graph.fql_query("SELECT type, created_time, post_id, actor_id, message, description, comment_info, like_info FROM stream WHERE filter_key = 'nf' LIMIT 15")
			puts "here is the feed"

			@feed.each_with_index do |f,i|
				# ignor comment created posts
				if f['type'] == 257
					@feed.delete_at i
					next
				end

				post_id=f['post_id']
				puts "your post id's are #{post_id}"
				
				begin
					f['details'] = get_post_details post_id, graph
					f['profile_pic'] = get_profile_pic f['actor_id']

					puts "\n\nProfile pic #{f['profile_pic']}\n\n"
				rescue Exception => e
					puts "Error fetching details for post, deleting from feed #{post_id}"
					puts e.inspect
					puts e.message
					@feed.delete_at i
				end
			end
			settings.cache.set('feed_key', @feed)
			end
			puts @feed.inspect

		end
	
		erb :index
	end
	
	get '/validate' do
		oauth = Koala::Facebook::OAuth.new(@@app_settings[:app_id], @@app_settings[:app_secret], @@app_settings[:callback_url])
		code=params['code']
		puts "code = #{code}"

		#puts access_token.inspect

		token=oauth.get_access_token(code)
		puts "Token #{token.inspect}"
		session[:token] = token

		redirect '/'
		session.inspect
	end

	get '/logout' do
		session[:token]=nil
		erb :index
	end

	get '/login' do
		@oauth = Koala::Facebook::OAuth.new(@@app_settings[:app_id], @@app_settings[:app_secret], @@app_settings[:callback_url])
		url_for_oauth = @oauth.url_for_oauth_code(:permissions	=> @@app_settings[:permissions])
		redirect url_for_oauth
	end

	get '/b_day' do

		token=session[:token]
		@graph = Koala::Facebook::API.new(token)
			@feed = @graph.get_connection('me','feed')
		@feed_key=@feed	
		erb :B_day_resp
	end

	get '/photos' do
		token=session[:token]
		@graph = Koala::Facebook::API.new(token)
			@feed = @graph.get_connection('me','feed')
		@feed_key=@feed
		erb :tagged_photos
	end


	post '/reply' do
		token=session[:token]
		puts "here is reply token"
		puts @token.inspect
		@graph = Koala::Facebook::API.new(token)
		post_id = params[:post_id]
		comment = params[:comment]
		puts "here is the comment"
		puts comment
		puts post_id
		@graph.put_comment(post_id, comment)
		"Posted '#{comment}' on Post '#{post_id}'"
	end

	post '/b_day_like' do
		token=session[:token]
		puts "adf"
		@graph = Koala::Facebook::API.new(token)
		#	if @feed_key.nil?
		#	@feed = @graph.get_connection('me','feed')
		#	settings.cache.set('feed_key', @feed)
		#	@feed_key = settings.cache.get('feed_key')
		#	end
		@feed_key.each do |f| 
			if f['type']=='status'
				if f['message']=="bla bla bla"
					@graph.put_like(f['id'])
				end 
			end
		end

	end

	post '/b_day_comment' do
		token=session[:token]
		puts "adf"
		graph = Koala::Facebook::API.new(token)
		#	if @feed_key.nil?
		#	@feed = @graph.get_connection('me','feed')
		#	settings.cache.set('feed_key', @feed)
		#	@feed_key = settings.cache.get('feed_key')
		#	end
		feed=graph.get_connection('me','feed')
		@feed_key=feed
		comment=params[:comment]
		@feed_key.each do |f| 
			if f['type']=='status'
				if f['message']=="bla bla bla"
					@graph.put_comment(f['id'],comment)
				end 
			end
		end

	end

end
