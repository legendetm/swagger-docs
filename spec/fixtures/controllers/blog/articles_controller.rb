module Blog
  class ArticlesController < ApplicationController
    swagger_controller :articles, "Blog Articles"

    swagger_api :index do
      summary "Fetches all Blog Articles"
      param :query, :page, :integer, :optional, "Page number"
      response :ok
      response :unauthorized
    end
  end
end
