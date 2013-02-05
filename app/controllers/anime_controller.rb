class AnimeController < ApplicationController
  def show
    @anime = Anime.find(params[:id])
    @genres = @anime.genres
    @producers = @anime.producers
    @quotes = @anime.quotes.limit(4)
    @castings = @anime.castings.includes(:character, :voice_actor)
    @reviews = @anime.reviews.includes(:user)

    respond_to do |format|
      format.html { render :show }
    end
  end

  def index
    # Establish a base scope, with pagination enabled.
    @anime = Anime.page(params[:page]).per(18).uniq

    # Get a list of all genres.
    @all_genres = Genre.order(:name)

    # Filter by genre if needed.
    if params[:genres] and params[:genres].length > 0
      @genre_slugs  = params[:genres].split.uniq 
      if @all_genres.count > @genre_slugs.length
        @genre_filter = Genre.where("slug IN (?)", @genre_slugs)
        @anime = @anime.joins(:genres)
                       .where("genres.id IN (?)", @genre_filter.map(&:id))
      end
    end
    @genre_filter ||= @all_genres

    # Fetch the user's watchlist.
    @watchlist = Hash.new(false)
    if user_signed_in?
      Watchlist.where(:user_id => current_user).each do |watch|
        @watchlist[ watch.anime_id ] = watch
      end
    end

    # What regular filter are we applying?
    @filter = params[:filter] || "all"

    if @filter == "unseen"

      # The user needs to be signed in for this one.
      authenticate_user!

      # Get anime which the user doesn't have on their watchlist.
      @anime = @anime.where('anime.id NOT IN (?)', @watchlist.keys)
      
    elsif @filter == "unfinished"

      @anime = @anime.where('anime.id IN (?)', @watchlist.keys)

    elsif @filter == "recommended"

      # The user needs to be signed in.
      authenticate_user!

      RecommendingWorker.perform_async(current_user.id)

      @recommendations = Recommendation.where(:user_id => current_user)
      @anime = @anime.where('anime.id IN (?)', @recommendations.map(&:anime_id))

    else
      # We don't have to do any filtering.
    end

    respond_to do |format|
      format.html { render :index }
    end
  end
end
