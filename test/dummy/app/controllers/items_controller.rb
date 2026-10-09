class ItemsController < ApplicationController
  def index; end

  def create
    @name = params[:name].to_s.strip
    render status: @name.empty? ? :unprocessable_entity : :ok
  end
end
