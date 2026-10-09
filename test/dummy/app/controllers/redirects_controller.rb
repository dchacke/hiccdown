class RedirectsController < ApplicationController
  # Every request here, so the system tests can tell how many a redirect
  # takes.
  cattr_accessor :requests, default: []

  before_action { requests << [request.request_method, request.path, request.format.to_sym] }

  def new; end

  def create
    redirect_to redirected_path
  end

  def show; end
end
